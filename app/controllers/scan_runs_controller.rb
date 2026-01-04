# app/controllers/scan_runs_controller.rb
class ScanRunsController < ApplicationController
  include ScanRunsHelper
  include RepositoryWorkspaceContext

  layout "repository_workspace", only: %i[index create destroy scanned_files scanned_occurrences]
  before_action :set_scan_run, only: %i[destroy scanned_occurrences scanned_files]

  def index
    repo_id = @selected_id || params[:repository_id].presence
    scope = if repo_id.present?
              ScanRun
                .joins(:repository_snapshot)
                .where(repository_snapshots: { repository_id: params[:repository_id] })
            else
              ScanRun.all
            end

    @scan_runs =
      scope
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
    file_ids = params[:file_ids].presence || []
    snapshot = @selected_repository.current_snapshot
    if snapshot.nil?
      flash[:alert] = "No repository snapshot found. Please import the repository first."
      return redirect_to(repositories_path(repository_id: @selected_repository.id))
    end
    @scan_run =
      ScanRun.new(
        lexical_pattern_id: @current_pattern.id,
        repository_snapshot_id: snapshot.id,
        started_at: Time.current,
        pattern_snapshot:
         {
           name: @current_pattern.name,
           scan_mode: @current_pattern.scan_mode,
           regexp: @current_pattern.pattern,
         },
      )
    if @scan_run.save
      flash[:success] = "Scan created and started."
      StartScanJob.perform_later(
        scan_run_id: @scan_run.id,
        repository_id: @selected_repository.id,
        file_ids: file_ids,
      )
      redirect_to(scan_runs_path(repository_id: @selected_repository.id))
    else
      flash[:error] = @scan_run.errors.full_messages.join(", ")
      redirect_to(repositories_path(repository_id: @selected_repository.id))
    end
  end

  def destroy
    @scan_run = ScanRun.find(params[:id])
    @scan_run.id
    if @scan_run.destroy!
      flash[:success] = "Scan run deleted."
      redirect_to scan_runs_path
    else
      flash[:error] = @scan_run.errors.full_messages.join(", ")
      redirect_to scan_runs_path
    end
  end

  def scanned_occurrences
    @occurrences =
      @scan_run.occurrences
        .includes(:repository_file)
        .order(:repository_file_id, :line_at, :line_char_start, :id)
        .page(params[:page])
        .per(10)
  end

  def scanned_files
    @scan_run_files =
      @scan_run.scan_run_files
        .includes(:repository_file)
        .order(:id)
        .page(params[:page])
        .per(20)
  end

  private

  def set_scan_run
    @scan_run = ScanRun.find(params[:id])
  end
end
