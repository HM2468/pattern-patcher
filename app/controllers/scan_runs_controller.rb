# app/controllers/scan_runs_controller.rb
class ScanRunsController < ApplicationController
  include ScanRunsHelper

  def index
    @scan_runs =
      ScanRun
        .joins(repository_snapshot: :repository)
        .joins(:lexical_pattern)
        .left_joins(:occurrences)
        .select(<<~SQL.squish)
          scan_runs.*,
          repositories.name AS repository_name,
          repository_snapshots.commit_sha AS commit_sha,
          lexical_patterns.name AS lexical_pattern_name,
          COUNT(occurrences.id) AS occurrences_count
        SQL
        .group("scan_runs.id, repositories.name, repository_snapshots.commit_sha, lexical_patterns.name")
        .order("scan_runs.created_at DESC")
        .page(params[:page])
        .per(10)

    # 进度条数据来自 cache（每页 10 次读取）
    @progress_by_id = {}
    @scan_runs.each do |sr|
      @progress_by_id[sr.id] = sr.read_progress
    end
  end

  def destroy
    scan_run = ScanRun.find(params[:id])
    scan_run.destroy!
    redirect_to scan_runs_path, notice: "Scan run deleted."
  end
end