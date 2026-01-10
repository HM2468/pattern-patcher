# app/controllers/lexemes_controller.rb
class LexemesController < ApplicationController
  include ProcessorWorkspaceContext
  layout "processor_workspace", only: %i[index show destroy update toggle_ignore]
  before_action :set_lexeme, only: %i[destroy update toggle_ignore]

  def index
    @status = params[:status].presence
    base = Lexeme
      .includes(occurrences: :repository_file)

    @pending_count   = Lexeme.pending.count
    @processed_count = Lexeme.processed.count
    @ignored_count   = Lexeme.ignored.count
    @failed_count    = Lexeme.failed.count

    @lexemes =
      case @status
      when "pending"   then base.pending
      when "processed" then base.processed
      when "ignored"   then base.ignored
      when "failed"    then base.failed
      else
        base
      end.page(params[:page]).per(15)

    # For each lexeme: list [{ occurrence_id, repository_file_path }, ...]
    @occurrence_links_by_lexeme_id =
      @lexemes.each_with_object({}) do |lex, h|
        h[lex.id] = lex.occurrences.map do |occ|
          { occurrence_id: occ.id, repository_file_path: occ.repository_file&.path.to_s }
        end
      end
  end

  def toggle_ignore
    return redirect_back(fallback_location: lexemes_path) if @lexeme.nil?

    # Only toggle between pending <-> ignored as requested
    next_status =
      case @lexeme.process_status
      when "ignored" then "pending"
      else
        "ignored"
      end

    @lexeme.update!(process_status: next_status)

    redirect_to lexemes_path(page: params[:page], status: params[:status]),
      notice: "Lexeme status updated."
  end

  def destroy
    return redirect_back(fallback_location: lexemes_path) if @lexeme.nil?

    @lexeme.destroy!
    redirect_to lexemes_path(page: params[:page], status: params[:status]),
      notice: "Lexeme deleted successfully."
  end

  def update
    return redirect_back(fallback_location: lexemes_path) if @lexeme.nil?

    if @lexeme.update(lexeme_params)
      redirect_to lexemes_path(page: params[:page], status: params[:status]),
        notice: "Lexeme updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def show; end

  private

  def set_lexeme
    @lexeme = Lexeme.find_by(id: params[:id])
  end

  def lexeme_params
    params.require(:lexeme).permit(:process_status)
  end
end