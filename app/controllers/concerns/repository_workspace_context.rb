# app/controllers/concerns/repository_workspace_context.rb
module RepositoryWorkspaceContext
  extend ActiveSupport::Concern

  included do
    before_action :init_current_pattern
    before_action :init_dropdown_list
    before_action :init_repo_params
    before_action :init_current_repository
    before_action :load_repository_counters, if: -> { needs_repository_counters? }
  end

  private

  # 1) Left sidebar: current lexical pattern
  # Kept for backward compatibility with existing views
  def init_current_pattern
    @current_pattern = LexicalPattern.current_pattern
  end

  # 2) Left sidebar: repository dropdown list (1 query)
  def init_dropdown_list
    @repositories = Repository.order(created_at: :desc).to_a
    @dropdown_list = @repositories.map { |r| { id: r.id, name: r.name } }
  end

  # 3) Resolve selected repository id + common params
  def init_repo_params
    @path_filter = params[:path_filter].to_s.strip

    # IMPORTANT:
    # params[:id] means different things in different controllers.
    # - repositories/:id        => repository id
    # - scan_runs/:id/*         => scan_run id (NOT repository id)
    #
    # Only treat params[:id] as repository_id when we are in RepositoriesController.
    repo_id_from_id_param =
      controller_name == "repositories" ? params[:id].presence : nil

    # Selected repository id (do NOT override controller-defined @repository)
    @selected_id =
      params[:repository_id].presence ||
      repo_id_from_id_param ||
      @repository&.id ||
      @repositories.first&.id
  end

  # 4) Resolve current repository object (0 extra queries)
  def init_current_repository
    @current_repository =
      if defined?(@repository) && @repository&.id.to_s == @selected_id.to_s
        @repository
      else
        @repositories.find { |r| r.id == @selected_id.to_i }
      end
  end

  # 5) Decide whether counters are needed
  def needs_repository_counters?
    controller_name.in?(%w[repositories repository_files scan_runs]) &&
      action_name.in?(%w[index show edit])
  end

  # 6) Repository statistics (executed only when needed)
  def load_repository_counters
    repo_id = @current_repository&.id
    return if repo_id.blank?

    @file_count = RepositoryFile.where(repository_id: repo_id).count
    @scan_count = scan_count_for(repo_id)
  end

  def scan_count_for(repo_id)
    ScanRun
      .joins(:repository_snapshot)
      .where(repository_snapshots: { repository_id: repo_id })
      .count
  end
end