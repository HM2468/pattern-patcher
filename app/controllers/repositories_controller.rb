# app/controllers/repositories_controller.rb
class RepositoriesController < ApplicationController
  def index
    @repositories = Repository.order(name: :asc)

    if @repositories.empty?
      @current_repo = nil
      @path_filter = ""
      @repository_files = RepositoryFile.none.page(params[:page]).per(200)
      return
    end

    repository_id = params[:repository_id].presence || @repositories.first.id
    @current_repo = Repository.find_by(id: repository_id) || @repositories.first
    @path_filter = params[:path_filter].to_s.strip

    @repository_files =
      @current_repo.repository_files
                  .path_starts_with(@path_filter) # scope 已经处理 blank => all
                  .by_path                        # 建议保持稳定排序
                  .page(params[:page])
                  .per(200)
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