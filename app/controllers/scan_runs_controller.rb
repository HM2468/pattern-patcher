class ScanRunsController < ApplicationController
  def index
  end

  def show
  end

  def create
    if LexicalPattern.current_pattern.nil?
      flash[:alert] = "No enabled pattern found. Please set up one in Lexical Patterns page."
      redirect_to repositories_path(repository_id: params[:repository_id])
    end
  end
end
