# app/controllers/lexemes_controller.rb
class LexemesController < ApplicationController
  include ProcessorWorkspaceContext
  layout "processor_workspace", only: %i[index show destroy update toggle_ignore]
  before_action :set_lexeme, only: %i[destroy update toggle_ignore]

  def index
    @status = params[:status].presence
    @text_filter = params[:text_filter].to_s.strip
    @path_filter = params[:path_filter].to_s.strip

    base = Lexeme.all

    # ===== Status filter =====
    base =
      case @status
      when "pending"   then base.pending
      when "processed" then base.processed
      when "ignored"   then base.ignored
      when "failed"    then base.failed
      else
        base
      end

    # ===== Text filter (lexeme.source_text) =====
    if @text_filter.present?
      base = base.where("lexemes.source_text ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@text_filter)}%")
    end

    # ===== Path filter (occurrence.repository_file.path) =====
    if @path_filter.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@path_filter)
      base = base.joins(occurrences: :repository_file).where("repository_files.path ILIKE ?", "%#{escaped}%").distinct
    end

    # Counts (counts are for all statuses, not affected by search)
    @pending_count   = Lexeme.pending.count
    @processed_count = Lexeme.processed.count
    @ignored_count   = Lexeme.ignored.count
    @failed_count    = Lexeme.failed.count

    @lexemes = base.includes(occurrences: :repository_file).order(source_text: :asc).page(params[:page]).per(15)

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