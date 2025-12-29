class LexemeProcessJobsController < ApplicationController
  include LexemeWorkspaceSection

  def index
    @lexeme_process_jobs =
      LexemeProcessJob
        .includes(:lexeme_processor)
        .order(created_at: :desc)
  end

  def destroy
  end
end
