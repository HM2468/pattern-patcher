class ProcessRunsController < ApplicationController
  include ProcessorWorkspaceContext
  layout "processor_workspace", only: %i[index]
  before_action :set_lexeme_processor, only: %i[create]
  before_action :set_process_run, only: %i[destroy]

  def index
    processor_id = @current_processor.id || params[:processor_id].presence
    base_scope =
      if processor_id.present?
        ProcessRun.where(lexeme_processor_id: processor_id)
      else
        ProcessRun.all
      end
    @process_runs =
      base_scope
        .includes(:lexeme_processor)
        .order(created_at: :desc)
        .page(params[:page])
        .per(10)
    @progress_by_id = {}
    @process_runs.each do |pr|
      @progress_by_id[pr.id] = pr.read_progress
    end
  end

  def create
    @process_run = @lexeme_processor.process_runs.build(status: "pending")
    if @process_run.save
      flash[:success] = "Process run created successfully."
      LexemeProcessDispatcherJob.perform_later(@process_run.id)
      redirect_to process_runs_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    run_id = @process_run.id
    @process_run.destroy!
    ProcessRunRollbackJob.perform_later(process_run_id: run_id)
    flash[:success] = "Process run deleted successfully."
    redirect_to process_runs_path
  end

  private

  def set_lexeme_processor
    @lexeme_processor = LexemeProcessor.find_by(id: params[:lexeme_processor_id])
  end

  def set_process_run
    @process_run = ProcessRun.find_by(id: params[:id])
  end
end
