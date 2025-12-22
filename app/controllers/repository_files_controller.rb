class RepositoryFilesController < ApplicationController
  def bulk_delete
    @repository = Repository.find(params[:repository_id])
    @repository_files = @repository.repository_files.where(id: params[:file_ids])
    @repository_files.destroy_all
    head :no_content
  end
end
