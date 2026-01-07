# app/controllers/scan_runs_controller.rb
class ScanRunsController < ApplicationController
  include ScanRunsHelper
  include RepositoryWorkspaceContext

  layout "repository_workspace", only: %i[index create destroy scanned_files]
  before_action :set_scan_run, only: %i[destroy scanned_occurrences scanned_files]

  def index
    repo_id = @selected_id.presence || params[:repository_id].presence
    base_scope =
      if repo_id.present?
        ScanRun
          .joins(:repository_snapshot)
          .where(repository_snapshots: { repository_id: repo_id })
      else
        ScanRun.all
      end

    @scan_runs =
      base_scope
        .joins(repository_snapshot: :repository)
        .select(<<~SQL.squish)
          scan_runs.*,
          repositories.name AS repository_name,
          repository_snapshots.commit_sha AS commit_sha
        SQL
        .order("scan_runs.created_at DESC")
        .page(params[:page])
        .per(5)

    @progress_by_id = {}
    @scan_runs.each { |sr| @progress_by_id[sr.id] = sr.read_progress }
  end


  def create
    file_ids = params[:file_ids].presence || []
    snapshot = @current_repository.current_snapshot

    if snapshot.nil?
      flash[:alert] = "No repository snapshot found. Please import the repository first."
      return redirect_to(repositories_path(repository_id: @current_repository.id))
    end

    @scan_run =
      ScanRun.new(
        lexical_pattern_id: @current_pattern.id,
        repository_snapshot_id: snapshot.id,
        started_at: Time.current,
        pattern_snapshot: {
          name: @current_pattern.name,
          scan_mode: @current_pattern.scan_mode,
          regexp: @current_pattern.pattern,
        },
      )
    if @scan_run.save
      StartScanJob.perform_later(
        scan_run_id: @scan_run.id,
        repository_id: @current_repository.id,
        file_ids: file_ids,
      )
      repo_id = @current_repository.id
      repository = @current_repository
      scan_count = get_scan_count(repo_id)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              view_context.dom_id(repository, :scan_count),
              partial: "repositories/scan_count",
              locals: { repository: repository, scan_count: scan_count }
            ),
            view_context.turbo_stream_action_tag("redirect", url: scan_runs_path(repository_id: repo_id))
          ]
        end
        format.html do
          flash[:success] = "Scan created and started."
          redirect_to scan_runs_path(repository_id: repo_id)
        end
      end
    else
      flash[:error] = @scan_run.errors.full_messages.join(", ")
      redirect_to(repositories_path(repository_id: @current_repository.id))
    end
  end

  def destroy
    repo_id =
      params[:repository_id].presence ||
      @scan_run.repository_snapshot&.repository_id

    repository = Repository.find(repo_id)
    @scan_run.destroy!
    scan_count = get_scan_count(repo_id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            view_context.dom_id(repository, :scan_count),
            partial: "repositories/scan_count",
            locals: { repository: repository, scan_count: scan_count }
          ),
          view_context.turbo_stream_action_tag("redirect", url: scan_runs_path(repository_id: repo_id))
        ]
      end

      format.html do
        flash[:success] = "Scan run deleted."
        redirect_to scan_runs_path(repository_id: repo_id)
      end
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    flash[:error] = e.message
    redirect_to scan_runs_path(repository_id: repo_id)
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
