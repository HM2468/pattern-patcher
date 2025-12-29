class LexemeProcessJobsController < ApplicationController
  include LexemeWorkspaceSection
  before_action :set_lexeme_processor, only: %i[create]
  before_action :set_lexeme_process_job, only: %i[destroy]

  def index
    @lexeme_process_jobs =
      LexemeProcessJob
        .includes(:lexeme_processor)
        .order(created_at: :desc)
  end

  def create
    @lexeme_process_job = @lexeme_processor.lexeme_process_jobs.build(status: "pending")
    if @lexeme_process_job.save
      flash[:success] = "Process job created successfully."
      redirect_to lexeme_process_jobs_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @lexeme_process_job.destroy!
    flash[:success] = "Process job deleted successfully."
    redirect_to lexeme_process_jobs_path
  end

  private

  def set_lexeme_processor
    @lexeme_processor = LexemeProcessor.find_by(id: params[:lexeme_processor_id])
  end

  def set_lexeme_process_job
    @lexeme_process_job = LexemeProcessJob.find_by(id: params[:id])
  end
end
