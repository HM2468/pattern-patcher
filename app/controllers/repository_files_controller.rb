class RepositoryFilesController < ApplicationController
  PER_PAGE = 200

  def index
    @repository = Repository.find(params[:repository_id])
    @repository_files = @repository.repository_files.order(path: :asc).page(params[:page]).per(PER_PAGE)
  end

  def show
  end

  def new
  end

  def edit
  end
end
