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

  def create
    @repository = Repository.find_by(id: params[:repository_id])
    unless @repository
      flash[:alert] = "Repository not found."
      return redirect_to(repositories_path)
    end

    scan_pattern = LexicalPattern.current_pattern
    if scan_pattern.nil?
      flash[:alert] = "No enabled pattern found. Please set up one in Lexical Patterns page."
      return redirect_to(repositories_path(repository_id: @repository.id))
    end

    file_ids = params[:file_ids].presence || []
    snapshot = @repository.current_snapshot
    if snapshot.nil?
      flash[:alert] = "No repository snapshot found. Please import the repository first."
      return redirect_to(repositories_path(repository_id: @repository.id))
    end
    @scan_run =
      ScanRun.new(
        lexical_pattern_id: scan_pattern.id,
        repository_snapshot_id: snapshot.id,
        scan_mode: scan_pattern.mode,
        status: "pending",
        started_at: Time.current,
        pattern_snapshot: scan_pattern.pattern
      )
    if @scan_run.save
      flash[:success] = "Scan created and started."
      StartScanJob.perform_later(
        scan_run_id: @scan_run.id,
        repository_id: @repository.id,
        file_ids: file_ids
      )
      redirect_to(scan_runs_path(repository_id: @repository.id))
    else
      flash[:error] = @scan_run.errors.full_messages.join(", ")
      redirect_to(repositories_path(repository_id: @repository.id))
    end
  end

  def destroy
    scan_run = ScanRun.find(params[:id])
    scan_run.destroy!
    redirect_to scan_runs_path, notice: "Scan run deleted."
  end
end