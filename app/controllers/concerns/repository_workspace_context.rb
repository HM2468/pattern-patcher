# app/controllers/concerns/repository_workspace_context.rb
module RepositoryWorkspaceContext
  extend ActiveSupport::Concern

  included do
    before_action :prepare_repository_workspace
  end

  private

  def prepare_repository_workspace
    # 1) Left sidebar @current_pattern
    @current_pattern = LexicalPattern.current_pattern

    # 2) Left sidebar list (1 query)
    @repositories  = Repository.order(name: :asc).to_a
    @dropdown_list = @repositories.map { |r| { id: r.id, name: r.name } }
    @path_filter   = params[:path_filter].to_s.strip

    # IMPORTANT:
    # params[:id] means different things in different controllers.
    # - repositories/:id        => repo id
    # - scan_runs/:id/*         => scan_run id (NOT repo id)
    #
    # Only treat params[:id] as repository_id when we are in RepositoriesController.
    repo_id_from_id_param =
      controller_name == "repositories" ? params[:id].presence : nil

    # 3) Selected repo id (don't override controller's @repository)
    @selected_id =
      params[:repository_id].presence ||
      repo_id_from_id_param ||
      @repository&.id ||
      @repositories.first&.id

    # 4) Workspace selected repo object: prioritize controller's @repository, then find from list (0 query)
    @selected_repository =
      if defined?(@repository) && @repository&.id.to_s == @selected_id.to_s
        @repository
      else
        @repositories.find { |r| r.id == @selected_id.to_i }
      end

    # 5) Statistics: calculate only when needed (optional)
    load_repository_counters if needs_repository_counters?
  end

  def needs_repository_counters?
    # Adjust as needed: which controller/actions need to display statistics
    controller_name.in?(%w[repositories repository_files scan_runs]) &&
      action_name.in?(%w[index show edit])
  end

  def load_repository_counters
    repo_id = @selected_repository&.id
    return if repo_id.blank?

    # Two count queries (stable and clear)
    @file_count = RepositoryFile.where(repository_id: repo_id).count
    @scan_count = ScanRun
      .joins(:repository_snapshot)
      .where(repository_snapshots: { repository_id: repo_id })
      .count
  end
end