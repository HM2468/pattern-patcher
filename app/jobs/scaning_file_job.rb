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
    total = pending_scope.count
    done = 0
    failed = 0
    @scan_run.update!(status: "running", started_at: (@scan_run.started_at || Time.current))
    write_progress(total: total, done: done, failed: failed)
    pending_scope.find_each(batch_size: BATCH_SIZE) do |scan_file|
      ok = process_one_scan_file!(scan_file)
      if ok
        done += 1
      else
        failed += 1
      end
      write_progress(total: total, done: done, failed: failed)
    end
    finalize!(total: total, done: done, failed: failed)
  rescue => e
    fail_run!(e)
    raise
  end

  private

  def load_context!(scan_run_id)
    @scan_run = ScanRun.find(scan_run_id)
    snapshot = @scan_run.repository_snapshot
    @repo    = snapshot&.repository
    @pattern = @scan_run.lexical_pattern

    raise "Pattern not found for scan_run=#{@scan_run.id}" unless @pattern
    raise "Repository not found for scan_run=#{@scan_run.id}" unless @repo
  end

  def pending_scope
    @scan_run.scan_run_files
             .where(status: "pending")
             .includes(:repository_file)
             .order(:id)
  end


  # Work
  # @return [Boolean] true if finished, false if failed
  def process_one_scan_file!(scan_file)
    scan_file.update!(status: "scanning")
    repo_file = scan_file.repository_file
    raise "RepositoryFile missing for scan_run_file=#{scan_file.id}" unless repo_file

    FileScanService.new(
      repository: @repo,
      scan_run: @scan_run,
      repo_file: repo_file,
      pattern: @pattern,
    ).execute
    scan_file.update!(status: "finished", error: nil)
    true
  rescue => e
    scan_file.update(status: "failed", error: e.message.to_s)
    false
  end

  def write_progress(total:, done:, failed:, error: nil)
    @scan_run.write_progress(
      @scan_run.progress_payload(
        phase: ScanRun::PHASES[1],
        total: total,
        done: done,
        failed: failed,
        error: error
      )
    )
  end

  def finalize!(total:, done:, failed:)
    final_status = failed.positive? ? "finished_with_errors" : "finished"
    @scan_run.update!(status: final_status, finished_at: Time.current)
    write_progress(total: total, done: done, failed: failed)
  end

  def fail_run!(error)
    return unless defined?(@scan_run) && @scan_run

    @scan_run.update(
      status: "failed",
      error: error.message.to_s,
      finished_at: Time.current
    ) rescue nil

    begin
      total = pending_scope.count
      write_progress(total: total, done: 0, failed: 0, error: error.message.to_s)
    rescue
      nil
    end
  end
end