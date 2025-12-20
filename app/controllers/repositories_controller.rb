# app/controllers/repositories_controller.rb
class RepositoriesController < ApplicationController
  PER_PAGE = 200

  def index
    @repositories = Repository.order(created_at: :desc).to_a

    @selected_repo =
      if params[:id].present?
        @repositories.find { |r| r.id == params[:id].to_i }
      elsif params[:repository_id].present?
        @repositories.find { |r| r.id == params[:repository_id].to_i }
      else
        @repositories.first
      end

    @page = [params[:page].to_i, 1].max

    if @selected_repo
      scope = @selected_repo.repository_files.order(path: :asc)
      @total_files = scope.count
      @files = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    else
      @total_files = 0
      @files = []
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
    RepositoryImportJob.perform_now(repo.id)
    redirect_to repositories_path(repository_id: repo.id), notice: "Re-import job enqueued."
  end

  private

  def repository_params
    params.require(:repository).permit(:name, :root_path, :permitted_ext, :status)
  end
end