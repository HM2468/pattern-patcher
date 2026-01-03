# app/controllers/repositories_controller.rb
class RepositoriesController < ApplicationController
  include RepositoryWorkspaceContext
  before_action :set_repository, only: %i[show edit update destroy import]
  layout "repository_workspace", only: %i[index new edit update]

  def index
    if @selected_id.present?
      redirect_to repository_files_path(repository_id: @selected_id, path_filter: @path_filter)
    end
  end

  def show
    render :show, layout: false if turbo_frame_request?
  end

  def new
    @repository = Repository.new
    render_repo_right(:new)
  end

  def create
    @repository = Repository.new(repository_params)

    if @repository.save
      flash[:success] = "Repository created successfully. File importing job enqueued."
      redirect_to repositories_path(repository_id: @repository.id)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @confirm_message = {
      delete: {
        confirm_title: "Delete repository",
        confirm_confirm_label: "Delete",
        confirm_message: "Delete this repository? This cannot be undone."
      },
      import: {
        confirm_title: "Import files",
        confirm_confirm_label: "Import",
        confirm_message: "Import files from this repository?"
      }
    }
    render_repo_right(:edit)
  end

  def update
    if @repository.update(repository_params)
      flash[:success] = "Repository updated successfully."
      redirect_to repositories_path(repository_id: @repository.id)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @repository.destroy
      flash[:success] = "Repository deleted successfully. Cleaning up associated files."
      redirect_to repositories_path
    else
      flash[:error] = @repository.errors.full_messages.to_sentence.presence || "Failed to delete repository."
      redirect_to repositories_path(repository_id: @repository.id)
    end
  end

  def import
    RepositoryImportJob.perform_later(@repository.id)
    flash[:success] = "File importing job enqueued."
    redirect_to repositories_path(repository_id: @repository.id)
  end

  private

  def set_repository
    @repository = Repository.find_by(id: params[:id])
    unless @repository
      redirect_to repositories_path, flash: { error: "Repository not found." }
      nil
    end
  end

  def repository_params
    params.require(:repository).permit(:name, :root_path, :permitted_ext)
  end
end
