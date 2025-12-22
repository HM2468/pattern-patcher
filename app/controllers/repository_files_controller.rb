class RepositoryFilesController < ApplicationController
  def bulk_delete
    @repository = Repository.find(params[:repository_id])
    @repository_files = @repository.repository_files.where(id: params[:file_ids])
    @repository_files.destroy_all
    redirect_to repositories_path(repository_id: @repository.id), notice: "Files deleted successfully."
  end
end
