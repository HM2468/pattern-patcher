# frozen_string_literal: true

# app/jobs/start_scan_job.rb
class StartScanJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 500
  SRF_UNIQUE_INDEX_NAME = "index_scan_run_files_on_scan_run_and_repo_file_unique"

  # Responsibilities:
  # 1) Create ScanRunFile rows (join table) in batches.
  # 2) Write "persisting progress" into cache (via ScanRun model).
  # 3) Enqueue ScaningFileJob right after persistence is done.
  #
  # @param scan_run_id [Integer]
  # @param repository_id [Integer]
  # @param file_ids [Array<Integer>] empty means "scan all repository_files"
  #
  def perform(scan_run_id:, repository_id:, file_ids: [])
    @scan_run = ScanRun.find(scan_run_id)
    @repo     = Repository.find(repository_id)
    ids = normalize_ids(file_ids)
    @files_scope =
      if ids.empty?
        @repo.repository_files
      else
        @repo.repository_files.where(id: ids)
      end
    persist_scan_run_files!
    ScaningFileJob.perform_now(scan_run_id: @scan_run.id)
  end

  private

  def persist_scan_run_files!
    @scan_run.update!(status: "running", started_at: Time.current)
    total   = @files_scope.count
    created = 0
    @scan_run.write_persisting_progress(
      @scan_run.persisting_payload(
        status: "running",
        total: total,
        done: created
      )
    )

    @files_scope.order(:id).in_batches(of: BATCH_SIZE) do |batch|
      batch_ids = batch.pluck(:id)
      next if batch_ids.empty?

      now = Time.current
      rows = batch_ids.map do |repo_file_id|
        {
          scan_run_id: @scan_run.id,
          repository_file_id: repo_file_id,
          status: "pending",
          created_at: now,
          updated_at: now
        }
      end

      # Idempotent insert (unique index prevents duplicates)
      ScanRunFile.insert_all(rows, unique_by: SRF_UNIQUE_INDEX_NAME)
      created += rows.size
      @scan_run.write_persisting_progress(
        @scan_run.persisting_payload(
          status: "running",
          total: total,
          done: created
        )
      )
    end

    # Mark persisting phase done; scanning continues in ScaningFileJob.
    @scan_run.write_persisting_progress(
      @scan_run.persisting_payload(
        status: "ready_to_scan",
        total: total,
        done: created
      )
    )
  rescue => e
    @scan_run.update(
      status: "failed",
      error: e.message.to_s,
      finished_at: Time.current
    )
    @scan_run.write_persisting_progress(
      @scan_run.persisting_payload(
        status: "failed",
        total: 0,
        done: 0,
        error: e.message.to_s
      )
    )
    raise
  end

  def normalize_ids(file_ids)
    Array(file_ids)
      .map { |x| x.to_s.strip }
      .reject(&:empty?)
      .map(&:to_i)
      .uniq
  end
end