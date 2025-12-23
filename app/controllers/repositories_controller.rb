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
    @repository = Repository.new(status: "active")
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
    @repository = Repository.find(params[:id])
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
    @repository = Repository.find(params[:id])
    if @repository.update(repository_params)
      flash[:success] = "Repository updated successfully."
      redirect_to repositories_path(repository_id: @repository.id)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Repository.find(params[:id]).destroy
    flash[:success] = "Repository deleted successfully."
    redirect_to repositories_path
  end

  def import
    repo = Repository.find(params[:id])
    RepositoryImportJob.perform_later(repo.id)
    flash[:success] = "File importing job enqueued."
    redirect_to repositories_path(repository_id: @repository.id)
  end

  private

  def repository_params
    params.require(:repository).permit(:name, :root_path, :permitted_ext)
  end
end