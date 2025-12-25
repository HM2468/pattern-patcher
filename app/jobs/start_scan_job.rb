# frozen_string_literal: true

class StartScanJob < ApplicationJob
  queue_as :default

  require "digest"
  require "json"

  # StartScanJob 做两件事：
  # 1) 创建 ScanRunFile（file_ids 为空 => 扫描全部 repository_files）
  # 2) 基于 ScanRunFile 执行 scan，并把进度写进 Redis
  #
  # @param scan_run_id [Integer]
  # @param repository_id [Integer]
  # @param file_ids [Array<Integer>] 可为空数组
  #
  def perform(scan_run_id:, repository_id:, file_ids: [])
    scan_run = ScanRun.find(scan_run_id)
    repo     = Repository.find(repository_id)

    files_scope =
      if file_ids.empty?
        repo.repository_files
      else
        repo.repository_files.where(id: file_ids)
      end

    repository_files = files_scope.order(:id).to_a
    total = repository_files.size

    # 标记 scan_run 状态 & 初始化 cursor + redis 进度
    scan_run.update!(
      status: "running",
      cursor: {
        total: total,
        done: 0,
        failed: 0,
        started_at: Time.current.iso8601
      }
    )
    write_progress(scan_run_id, total: total, done: 0, failed: 0, status: "running")

    # 1) 批量创建 ScanRunFile（幂等：unique (scan_run_id, repository_file_id)）
    now = Time.current
    rows =
      repository_files.map do |rf|
        {
          scan_run_id: scan_run.id,
          repository_file_id: rf.id,
          status: "pending",
          created_at: now,
          updated_at: now
        }
      end

    if rows.any?
      # Rails 7+ / 8: insert_all + unique_by
      # unique_by 的名字要匹配你 migration 里 unique index 的名字
      ScanRunFile.insert_all(rows, unique_by: "index_scan_run_files_on_scan_run_and_repo_file_unique")
    end

    # 2) 执行扫描（逐文件），并写进度到 Redis
    regex = safe_compile_regex!(scan_run.pattern_snapshot)

    done = 0
    failed = 0

    ScanRunFile.where(scan_run_id: scan_run.id).includes(:repository_file).order(:id).find_each do |srf|
      begin
        srf.update!(status: "scanning")

        scan_one_file!(
          repo: repo,
          scan_run: scan_run,
          scan_run_file: srf,
          repository_file: srf.repository_file,
          regex: regex
        )

        srf.update!(status: "finished")
        done += 1
      rescue => e
        failed += 1
        srf.update(status: "failed", error: e.message.to_s)
      ensure
        # 更新 redis 进度（前端轮询用）
        write_progress(scan_run.id, total: total, done: done, failed: failed, status: "running")

        # 同时也把 cursor 写回 DB（可选但推荐：方便恢复/审计）
        scan_run.update(cursor: scan_run.cursor.merge(done: done, failed: failed))
      end
    end

    final_status = (failed > 0 ? "finished_with_errors" : "finished")
    scan_run.update!(status: final_status, finished_at: Time.current)
    write_progress(scan_run.id, total: total, done: done, failed: failed, status: final_status, finished_at: Time.current.iso8601)
  rescue => e
    # scan_run 层面的致命错误
    ScanRun.where(id: scan_run_id).update_all(status: "failed", error: e.message.to_s, finished_at: Time.current)
    write_progress(scan_run_id, total: 0, done: 0, failed: 0, status: "failed", error: e.message.to_s)
    raise
  end

  private

  # -----------------------------
  # core scan logic (minimal runnable)
  # -----------------------------
  def scan_one_file!(repo:, scan_run:, scan_run_file:, repository_file:, regex:)
    # 读取 blob 内容（从 Git object）
    content = repo.git_cli.read_file(repository_file.blob_sha)

    # 行扫描（最小版本：每个 match 创建 lexeme + occurrence）
    content.to_s.each_line.with_index(1) do |line, line_no|
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

    # 你也可以把“文件扫描时间”写回去（可选）
    repository_file.update(last_scanned_at: Time.current)
  end

  def find_or_create_lexeme!(source_text)
    normalized = normalize_text(source_text)
    fingerprint = Digest::SHA256.hexdigest(normalized)

    Lexeme.find_or_create_by!(fingerprint: fingerprint) do |lx|
      lx.source_text = source_text.to_s
      lx.normalized_text = normalized
      lx.locale = "zh" # 你可以替换为自动检测/仓库默认
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
  # redis progress
  # -----------------------------
  def write_progress(scan_run_id, payload)
    key = redis_progress_key(scan_run_id)

    # 你也可以换成 Rails.cache（如果你把 cache_store 配成 redis）
    redis.set(key, payload.to_json)
    redis.expire(key, 86_400) # 24h
  rescue => e
    Rails.logger&.warn("[StartScanJob] failed to write redis progress: #{e.message}")
  end

  def redis_progress_key(scan_run_id)
    "patternpatcher:scan_runs:#{scan_run_id}:progress"
  end

  def redis
    @redis ||= if defined?(Redis)
      # 如果你有 REDIS_URL，就用它；否则默认本机
      Redis.new(url: ENV["REDIS_URL"])
    else
      raise "Redis gem not available"
    end
  end
end