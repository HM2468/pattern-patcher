# app/controllers/repositories_controller.rb
class RepositoriesController < ApplicationController
  before_action :get_repository, only: %i[edit update destroy import]

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
    @current_pattern = LexicalPattern.current_pattern
    @scan_hint_message = if @current_pattern.nil?
                           "No enabled pattern found. Please set up one in
                            <a href='#{lexical_patterns_path}' class='underline'>Lexical Patterns</a> page."
                         else
                           "Scan selected files with pattern: <strong>#{@current_pattern.name}</strong>?
                            Or change <a href='#{lexical_patterns_path}' class='underline'>current pattern</a>."
                         end.html_safe
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
      RepositoryCleanJob.perform_later(@repository.id)
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

  def get_repository
    @repository = Repository.find_by(id: params[:id])
    unless @repository
      redirect_to repositories_path, flash: { error: "Repository not found." }
      return
    end
  end

  def repository_params
    params.require(:repository).permit(:name, :root_path, :permitted_ext)
  end
end