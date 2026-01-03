# app/controllers/repositories_controller.rb
class RepositoriesController < ApplicationController
  before_action :set_repository, only: %i[show edit update destroy import]

  layout "repository_workspace", only: %i[new edit update]

  def index
    @repositories = Repository.order(name: :asc)
    @dropdown_list = @repositories.map { |repo| { id: repo.id, name: repo.name } }

    @selected_id = params[:repository_id].presence || @repositories.first&.id
    @path_filter = params[:path_filter].to_s.strip
  end

  def show
    respond_to do |format|
      format.html do
        render :show, layout: false
      end
      format.turbo_stream do
        render partial: "repositories/show",
              formats: [:html],
              locals: { repository: @repository }
      end
    end
  end

  def new
    @repository = Repository.new
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
