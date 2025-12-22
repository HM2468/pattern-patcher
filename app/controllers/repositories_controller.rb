# app/controllers/repositories_controller.rb
class RepositoriesController < ApplicationController
  def index
    # 仓库数量不多，不分页
    @repositories = Repository.order(name: :asc).all

    # 如果没有任何仓库，提前返回（这是 @current_repo 唯一可能为空的情况）
    if @repositories.empty?
      @current_repo = nil
      @repository_files = RepositoryFile.none.page(params[:page]).per(200)
      @path_filter = ""
      return
    end

    # 默认选中第一个仓库
    repository_id = params[:repository_id].presence || @repositories.first.id
    @current_repo = Repository.find(repository_id)
    @path_filter = params[:path_filter].to_s
    scope = @current_repo.repository_files.order(path: :asc)

    # 前缀匹配搜索
    if @path_filter.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@path_filter)
      scope = scope.where("path LIKE ?", "#{escaped}%")
    end

    @repository_files = scope.page(params[:page]).per(200)
  end

  def new
    @repository = Repository.new(status: "active")
  end

  def create
    @repository = Repository.new(repository_params)

    if @repository.save
      redirect_to repositories_path(repository_id: @repository.id), notice: "Repository created. Import job enqueued."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    redirect_to repositories_path(repository_id: params[:id])
  end

  def import
    repo = Repository.find(params[:id])
    RepositoryImportJob.perform_later(repo.id)
    redirect_to repositories_path(repository_id: repo.id), notice: "Re-import job enqueued."
  end

  private

  def repository_params
    params.require(:repository).permit(:name, :root_path, :permitted_ext, :status)
  end
end