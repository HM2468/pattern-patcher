class RepositoryFilesController < ApplicationController
  def bulk_delete
    @repository = Repository.find(params[:repository_id])
    @repository_files = @repository.repository_files.where(id: params[:file_ids])
    @repository_files.destroy_all
    flash[:success] = "Files deleted successfully."
    redirect_to repositories_path(repository_id: @repository.id)
  end
end
