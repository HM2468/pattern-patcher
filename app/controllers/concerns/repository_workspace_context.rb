# app/controllers/concerns/repository_workspace_context.rb
module RepositoryWorkspaceContext
  extend ActiveSupport::Concern

  included do
    before_action :prepare_repository_workspace
  end

  private

  def prepare_repository_workspace
    @repositories = Repository.order(name: :asc)
    @dropdown_list = @repositories.map { |repo| { id: repo.id, name: repo.name } }

    @path_filter = params[:path_filter].to_s.strip

    # selected_id 来源：显式参数 > 当前 @repository > 默认第一个
    @selected_id =
      params[:repository_id].presence ||
      @repository&.id ||
      @repositories.first&.id
  end
end