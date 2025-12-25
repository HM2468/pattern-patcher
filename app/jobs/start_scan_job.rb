# frozen_string_literal: true

# app/jobs/start_scan_job.rb
class StartScanJob < ApplicationJob
  queue_as :default

  require "digest"
  require "json"

  BATCH_SIZE = 500
  SRF_UNIQUE_INDEX_NAME = "index_scan_run_files_on_scan_run_and_repo_file_unique"

  # This job does two things:
  # 1) Create ScanRunFile rows (join table) in batches.
  # 2) Scan files based on ScanRunFile rows, and write progress into Redis for frontend polling.
  #
  # @param scan_run_id [Integer]
  # @param repository_id [Integer]
  # @param file_ids [Array<Integer>] can be empty (meaning scan all files in repository)
  #
  def perform(scan_run_id:, repository_id:, file_ids: [])
    scan_run = ScanRun.find(scan_run_id)
    repo     = Repository.find(repository_id)

    # Build file scope. Keep it as a relation (do NOT .to_a for huge datasets).
    file_ids = Array(file_ids).map(&:to_s).map(&:strip).reject(&:empty?).map(&:to_i).uniq
    files_scope =
      if file_ids.empty?
        repo.repository_files
      else
        repo.repository_files.where(id: file_ids)
      end

    total = files_scope.count

    # Mark scan_run as running and initialize progress cursor.
    scan_run.update!(
      status: "running",
      started_at: scan_run.started_at || Time.current,
      cursor: {
        total: total,
        done: 0,
        failed: 0,
        created_scan_run_files: 0,
        started_at: Time.current.iso8601
      }
    )

    write_progress(scan_run.id, total: total, done: 0, failed: 0, status: "running")

    # Compile regex snapshot once. Fail early if invalid.
    regex = safe_compile_regex!(scan_run.pattern_snapshot)

    # 1) Create ScanRunFile rows in batches (idempotent via unique index).
    created_srf = 0

    files_scope.order(:id).in_batches(of: BATCH_SIZE) do |batch_relation|
      # Load only this batch into memory (<= 500).
      batch_files = batch_relation.to_a
      next if batch_files.empty?

      now = Time.current
      rows =
        batch_files.map do |rf|
          {
            scan_run_id: scan_run.id,
            repository_file_id: rf.id,
            status: "pending",
            created_at: now,
            updated_at: now
          }
        end

      # insert_all is efficient; unique_by relies on the unique index name.
      result = ScanRunFile.insert_all(rows, unique_by: SRF_UNIQUE_INDEX_NAME)
      # result.rows may be empty depending on adapter; fallback to count approximation:
      created_srf += rows.size

      # Update DB cursor & Redis progress for "creation" phase visibility.
      scan_run.update!(cursor: scan_run.cursor.merge(created_scan_run_files: created_srf))
      write_progress(scan_run.id, total: total, done: 0, failed: 0, status: "running", created_scan_run_files: created_srf)
    end

    # 2) Scan files based on ScanRunFile rows in batches.
    done = 0
    failed = 0

    ScanRunFile.where(scan_run_id: scan_run.id).order(:id).find_in_batches(batch_size: BATCH_SIZE) do |srfs|
      break if srfs.empty?

      # Prefetch repository_files for this batch to avoid N+1 and to keep memory bounded.
      repo_file_ids = srfs.map(&:repository_file_id)
      repo_files_by_id = RepositoryFile.where(id: repo_file_ids).index_by(&:id)

      srfs.each do |srf|
        rf = repo_files_by_id[srf.repository_file_id]
        unless rf
          failed += 1
          srf.update(status: "failed", error: "repository_file not found: #{srf.repository_file_id}")
          next
        end

        begin
          srf.update!(status: "scanning")

          scan_one_file!(
            repo: repo,
            scan_run: scan_run,
            scan_run_file: srf,
            repository_file: rf,
            regex: regex
          )

          srf.update!(status: "finished")
          done += 1
        rescue => e
          failed += 1
          srf.update(status: "failed", error: e.message.to_s)
        ensure
          # Persist progress frequently so frontend can update in near real-time.
          scan_run.update(cursor: scan_run.cursor.merge(done: done, failed: failed))
          write_progress(scan_run.id, total: total, done: done, failed: failed, status: "running")
        end
      end
    end

    final_status = (failed > 0 ? "finished_with_errors" : "finished")
    scan_run.update!(status: final_status, finished_at: Time.current)
    write_progress(
      scan_run.id,
      total: total,
      done: done,
      failed: failed,
      status: final_status,
      finished_at: Time.current.iso8601
    )
  rescue => e
    # A fatal job-level error (e.g. invalid regex, repo missing, git read failure)
    ScanRun.where(id: scan_run_id).update_all(
      status: "failed",
      error: e.message.to_s,
      finished_at: Time.current
    )
    write_progress(scan_run_id, total: 0, done: 0, failed: 0, status: "failed", error: e.message.to_s)
    raise
  end

  private

  # -----------------------------
  # Scanning logic (minimal runnable)
  # -----------------------------

  def scan_one_file!(repo:, scan_run:, scan_run_file:, repository_file:, regex:)
    # Read file content from Git object database by blob sha.
    content = repo.git_cli.read_file(repository_file.blob_sha).to_s

    # Scan line by line (simple, safe, and memory bounded per line).
    content.each_line.with_index(1) do |line, line_no|
      # Use scan enumerator to find multiple matches per line.
      matches = line.to_enum(:scan, regex).map { Regexp.last_match }.compact
      next if matches.empty?

      matches.each do |m|
        matched_text = m[0].to_s
        next if matched_text.strip.empty?

        lexeme = find_or_create_lexeme!(matched_text)

        Occurrence.create!(
          scan_run_id: scan_run.id,
          lexeme_id: lexeme.id,
          lexical_pattern_id: scan_run.lexical_pattern_id,
          repository_file_id: repository_file.id,
          line_at: line_no,
          idx_start: m.begin(0),
          idx_end: m.end(0) - 1,
          matched_text: matched_text,
          context_before: nil,
          context_after: nil,
          status: "unreviewed"
        )
      end
    end

    # Optional: mark file scanned time.
    repository_file.update(last_scanned_at: Time.current)
  end

  def find_or_create_lexeme!(source_text)
    normalized  = normalize_text(source_text)
    fingerprint = Digest::SHA256.hexdigest(normalized)

    Lexeme.find_or_create_by!(fingerprint: fingerprint) do |lx|
      lx.source_text = source_text.to_s
      lx.normalized_text = normalized
      lx.locale = "zh" # adjust if you have detection/default locale
      lx.metadata = {}
    end
  end

  def normalize_text(text)
    text.to_s.strip.gsub(/\s+/, " ")
  end

  def safe_compile_regex!(pattern_str)
    Regexp.new(pattern_str.to_s)
  rescue RegexpError => e
    raise "Invalid regex pattern_snapshot: #{e.message}"
  end

  # -----------------------------
  # Redis progress (frontend polling)
  # -----------------------------

  def write_progress(scan_run_id, payload)
    key = redis_progress_key(scan_run_id)
    redis.set(key, payload.to_json)
    redis.expire(key, 86_400) # keep for 24h
  rescue => e
    Rails.logger&.warn("[StartScanJob] Redis progress write failed: #{e.message}")
  end

  def redis_progress_key(scan_run_id)
    "patternpatcher:scan_runs:#{scan_run_id}:progress"
  end

  def redis
    @redis ||= Redis.new(url: ENV["REDIS_URL"])
  end
end