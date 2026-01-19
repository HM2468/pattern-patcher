# app/controllers/process_runs_controller.rb
class ProcessRunsController < ApplicationController
  include ProcessorWorkspaceContext

  layout "processor_workspace", only: %i[index create destroy]
  before_action :set_lexeme_processor, only: %i[create]
  before_action :set_process_run, only: %i[destroy]

  def index
    processor_id =
      params[:processor_id].presence ||
      @current_processor&.id

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
    unless @lexeme_processor
      flash[:error] = "Lexeme processor not found."
      return redirect_to(process_runs_path, status: :see_other)
    end

    @process_run = @lexeme_processor.process_runs.build(status: "pending")

    if @process_run.save
      LexemeProcessDispatcherJob.perform_later(@process_run.id)

      processor = @lexeme_processor
      process_count = processor.process_runs.count

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              view_context.dom_id(processor, :process_count),
              partial: "lexeme_processors/process_count",
              locals: { processor: processor, process_count: process_count }
            ),
            view_context.turbo_stream_action_tag(
              "redirect",
              url: process_runs_path(processor_id: processor.id)
            )
          ]
        end

        format.html do
          flash[:success] = "Process run created successfully."
          redirect_to process_runs_path(processor_id: processor.id), status: :see_other
        end
      end
    else
      flash[:error] = @process_run.errors.full_messages.join(", ")
      redirect_to process_runs_path(processor_id: @lexeme_processor&.id), status: :see_other
    end
  end

  def destroy
    unless @process_run
      flash[:error] = "Process run not found."
      return redirect_to(process_runs_path, status: :see_other)
    end

    run_id = @process_run.id
    processor = @process_run.lexeme_processor

    @process_run.destroy!
    ProcessRunRollbackJob.perform_later(process_run_id: run_id)

    process_count = processor.process_runs.count

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            view_context.dom_id(processor, :process_count),
            partial: "lexeme_processors/process_count",
            locals: { processor: processor, process_count: process_count }
          ),
          view_context.turbo_stream_action_tag(
            "redirect",
            url: process_runs_path(processor_id: processor.id)
          )
        ]
      end

      format.html do
        flash[:success] = "Process run deleted successfully."
        redirect_to process_runs_path(processor_id: processor.id), status: :see_other
      end
    end
  rescue ActiveRecord::RecordNotDestroyed => e
    flash[:error] = e.message
    redirect_to process_runs_path(processor_id: @process_run&.lexeme_processor_id), status: :see_other
  end

  private

  def set_lexeme_processor
    @lexeme_processor = LexemeProcessor.find_by(id: params[:lexeme_processor_id])
  end

  def set_process_run
    @process_run = ProcessRun.find_by(id: params[:id])
  end
end