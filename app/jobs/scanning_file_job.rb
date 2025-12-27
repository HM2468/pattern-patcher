# frozen_string_literal: true

# app/jobs/scanning_file_job.rb
#
# Scanning phase job:
# - Read pending ScanRunFile rows in batches (preload repository_file to avoid N+1).
# - Mark each ScanRunFile status as scanning/finished/failed.
# - Write progress via ScanRun model (Rails.cache), without doing COUNT queries per file.
#
class ScanningFileJob < ApplicationJob
  queue_as :scanning

  BATCH_SIZE = 500

  def perform(scan_run_id:)
    load_context!(scan_run_id)

    # job-local progress state
    @total = pending_scope.count
    @done = 0
    @failed = 0
    @occ_count = 0

    @scan_run.update!(status: "running", started_at: (@scan_run.started_at || Time.current))
    write_progress

    pending_scope.find_each(batch_size: BATCH_SIZE) do |scan_file|
      ok, count = process_one_scan_file!(scan_file)
      @occ_count += count.to_i
      ok ? @done += 1 : @failed += 1
      write_progress
    end

    finalize!
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
  # @return [Array(Boolean, Integer)] [ok, occ_count]
  def process_one_scan_file!(scan_file)
    occ_count = 0
    scan_file.update!(status: "scanning")
    repo_file = scan_file.repository_file
    raise "RepositoryFile missing for scan_run_file=#{scan_file.id}" unless repo_file

    occ_count = FileScanService.new(
      repository: @repo,
      scan_run: @scan_run,
      repo_file: repo_file,
      pattern: @pattern
    ).execute

    scan_file.update!(status: "finished", error: nil)
    [true, occ_count]
  rescue => e
    scan_file.update(status: "failed", error: e.message.to_s) rescue nil
    [false, occ_count]
  end

  def write_progress(error: nil)
    payload = init_progress_payload(error: error)
    @scan_run.write_progress(payload)
  end

  def finalize!
    final_status = @failed.to_i.positive? ? "finished_with_errors" : "finished"
    @scan_run.update!(status: final_status, finished_at: Time.current, progress_persisted: init_progress_payload)
    write_progress
  end

  def fail_run!(error)
    return unless defined?(@scan_run) && @scan_run
    payload = init_progress_payload(error: error)
    @scan_run.update(
      status: "failed",
      error: error.message.to_s,
      finished_at: Time.current,
      progress_persisted: payload
    ) rescue nil
    @scan_run.write_progress(payload)
  end

  def init_progress_payload(error: nil)
    @scan_run.progress_payload(
      phase: ScanRun::PHASES[1],
      total: @total.to_i,
      done: @done.to_i,
      failed: @failed.to_i,
      occ_count: @occ_count.to_i,
      error: error
    )
  end
end