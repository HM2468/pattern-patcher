# frozen_string_literal: true
class RepositoryFilesController < ApplicationController
  layout "repository_workspace", only: %i[index]

  def index
    @repository = Repository.find_by(id: params[:repository_id])
    @path_filter = params[:path_filter].to_s.strip

    scope =
      if @repository
        RepositoryFile.where(repository_id: @repository.id)
      else
        RepositoryFile.all
      end

    @repository_files =
      scope.path_starts_with(@path_filter)
           .by_path
           .page(params[:page])
           .per(200)

    init_scan_hint_message

    respond_to do |format|
      format.html do
        if turbo_frame_request?
          render :index, layout: false
        else
          render :index
        end
      end
    end
  end

  def bulk_delete
    @repository = Repository.find(params[:repository_id])
    @repository_files = @repository.repository_files.where(id: params[:file_ids])
    @repository_files.destroy_all
    flash[:success] = "Files deleted successfully."
    redirect_to repositories_path(repository_id: @repository.id)
  end

  private

  def init_scan_hint_message
    @current_pattern = LexicalPattern.current_pattern
    if @current_pattern.nil?
      @scan_hint_message = @scan_all_hint =
        "No enabled pattern found. Please set up one in
          <a href='#{lexical_patterns_path}' class='underline'>Lexical Patterns</a> page."
    else
      @scan_hint_message =
        "Scan selected files with pattern: <strong>#{@current_pattern.name}</strong>?
          Or change <a href='#{lexical_patterns_path}' class='underline'>current pattern</a>."
      @scan_all_hint =
        "Scan all files in <strong>#{@repository&.name}</strong> with pattern: <strong>#{@current_pattern.name}</strong>?
          Or change <a href='#{lexical_patterns_path}' class='underline'>current pattern</a>."
    end
  end
end