# frozen_string_literal: true

# app/jobs/scaning_file_job.rb
#
# Scanning phase job:
# - Read pending ScanRunFile rows in batches (preload repository_file to avoid N+1).
# - Mark each ScanRunFile status as scanning/finished/failed.
# - Write progress via ScanRun model (Rails.cache), without doing COUNT queries per file.
#
class ScaningFileJob < ApplicationJob
  queue_as :scanning

  BATCH_SIZE = 500

  def perform(scan_run_id:)
    load_context!(scan_run_id)

    # Total for progress: how many files we are going to scan in THIS run (pending only).
    total = pending_scope.count

    # Initialize counters without expensive per-file DB counts.
    done = 0
    failed = 0

    # Mark run as running if needed.
    @scan_run.update!(status: "running", started_at: (@scan_run.started_at || Time.current))

    write_progress(status: "running", total: total, done: done, failed: failed)

    # Scan pending files in batches; includes(:repository_file) prevents N+1 reads.
    pending_scope.find_each(batch_size: BATCH_SIZE) do |scan_file|
      ok = process_one_scan_file!(scan_file)

      if ok
        done += 1
      else
        failed += 1
      end

      # Persist progress frequently for frontend polling.
      write_progress(status: "running", total: total, done: done, failed: failed)
    end

    finalize!(total: total, done: done, failed: failed)
  rescue => e
    fail_run!(e)
    raise
  end

  private

  # Context / scopes
  def load_context!(scan_run_id)
    @scan_run = ScanRun.find(scan_run_id)

    # Assumes: ScanRun belongs_to :repository_snapshot
    snapshot = @scan_run.repository_snapshot
    @repo    = snapshot&.repository

    # Assumes: ScanRun belongs_to :lexical_pattern
    @pattern = @scan_run.lexical_pattern

    raise "Pattern not found for scan_run=#{@scan_run.id}" unless @pattern
    raise "Repository not found for scan_run=#{@scan_run.id}" unless @repo
  end

  def pending_scope
    @scan_run.scan_run_files
             .where(status: "pending")
             .includes(:repository_file) # avoid N+1 for scan_file.repository_file
             .order(:id)
  end


  # Work
  # @return [Boolean] true if finished, false if failed
  def process_one_scan_file!(scan_file)
    scan_file.update!(status: "scanning")

    repo_file = scan_file.repository_file
    raise "RepositoryFile missing for scan_run_file=#{scan_file.id}" unless repo_file

    # TODO: Replace with your real scanning implementation
    # FileScanService.new(
    #   repository: @repo,
    #   scan_run: @scan_run,
    #   repo_file: repo_file,
    #   pattern: @pattern,
    # ).execute

    scan_file.update!(status: "finished", error: nil)
    true
  rescue => e
    scan_file.update(status: "failed", error: e.message.to_s)
    false
  end


  # Progress (single entry)
  def write_progress(status:, total:, done:, failed:, error: nil)
    @scan_run.write_scanning_progress(
      @scan_run.scanning_payload(
        status: status,
        total: total,
        done: done,
        failed: failed,
        error: error
      )
    )
  end


  # Finalization / failure
  def finalize!(total:, done:, failed:)
    final_status = failed.positive? ? "finished_with_errors" : "finished"

    @scan_run.update!(status: final_status, finished_at: Time.current)
    write_progress(status: final_status, total: total, done: done, failed: failed)
  end

  def fail_run!(error)
    return unless defined?(@scan_run) && @scan_run

    @scan_run.update(
      status: "failed",
      error: error.message.to_s,
      finished_at: Time.current
    ) rescue nil

    # Best-effort progress write (avoid raising here).
    begin
      total = pending_scope.count
      write_progress(status: "failed", total: total, done: 0, failed: 0, error: error.message.to_s)
    rescue
      nil
    end
  end
end