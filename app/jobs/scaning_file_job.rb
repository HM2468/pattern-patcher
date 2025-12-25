# frozen_string_literal: true

# app/jobs/scaning_file_job.rb
#
# NOTE:
# - This job is intentionally kept as a "scanning phase" skeleton.
# - You can fill in the real scanning / occurrence / patch generation logic later.
#
class ScaningFileJob < ApplicationJob
  queue_as :scanning
  BATCH_SIZE = 500

  # Scanning phase job:
  # 1) Read pending ScanRunFile rows in batches.
  # 2) Mark each ScanRunFile status as scanning/finished/failed.
  # 3) Write progress into Redis for frontend polling.
  #
  # @param scan_run_id [Integer]
  #
  def perform(scan_run_id:)
    @scan_run_id = scan_run_id
    @scan_run    = ScanRun.find(scan_run_id)
    @snapshot = RepositorySnapshot.find_by(id: @scan_run.repository_snapshot_id)
    @repo     = @snapshot&.repository
    @pattern  = FlexicalPattern.find_by(id: @scan_run.lexical_pattern_id)

    raise "Pattern not found for scan_run=#{scan_run_id}" unless @pattern
    raise "Repository not found for scan_run=#{scan_run_id}" unless @repo
  end

end