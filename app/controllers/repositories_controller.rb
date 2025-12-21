# app/controllers/repositories_controller.rb
class RepositoriesController < ApplicationController
  PER_PAGE = 200

  def index
    # 仓库数量不多，不用翻页
    @repositories = Repository.order(created_at: :desc)
    repository_id = params[:repository_id] || @repositories.first&.id
    if repository_id
      @repository = Repository.find(repository_id)
      @repository_files = @repository.repository_files.order(path: :desc).page(params[:page]).per(200)
    end
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