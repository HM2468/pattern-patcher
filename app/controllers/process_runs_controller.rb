class ProcessRunsController < ApplicationController
  include LexemeWorkspaceSection
  before_action :set_lexeme_processor, only: %i[create]
  before_action :set_process_run, only: %i[destroy]

  def index
    @process_runs =
      ProcessRun
        .includes(:lexeme_processor)
        .order(created_at: :desc)
        .page(params[:page])
        .per(10)
    # 进度条数据来自 cache（每页 10 次读取）
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
    @process_run.destroy!
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
