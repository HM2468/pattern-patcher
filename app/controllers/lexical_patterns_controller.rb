class LexicalPatternsController < ApplicationController
  def index
    # Keep ordering predictable for operators:
    # priority asc, then newest first as a stable tie-breaker
    @lexical_patterns =
      LexicalPattern
        .order(priority: :asc, created_at: :desc)
        .page(params[:page])
        .per(10)
  end

  def destroy
    @lexical_pattern = LexicalPattern.find(params[:id])
    @lexical_pattern.destroy!

    # Re-load current page after delete. This is what enables "fill the gap".
    @lexical_patterns =
      LexicalPattern
        .order(priority: :asc, created_at: :desc)
        .page(params[:page])
        .per(10)

    # If we just deleted the last record on this page, go back one page.
    if @lexical_patterns.empty? && params[:page].to_i > 1
      redirect_to lexical_patterns_path(page: params[:page].to_i - 1)
      return
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to lexical_patterns_path(page: params[:page]) }
    end
  end

  # Toggle enabled via a tiny PATCH request (Turbo compatible)
  def toggle_enabled
    @lexical_pattern = LexicalPattern.find(params[:id])
    @lexical_pattern.update!(enabled: !@lexical_pattern.enabled)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          view_context.dom_id(@lexical_pattern, :enabled_toggle),
          partial: "lexical_patterns/enabled_toggle",
          locals: { lexical_pattern: @lexical_pattern }
        )
      end
      format.html { redirect_to lexical_patterns_path }
    end
  end

  # Placeholder for your future regex test page
  def test
    @lexical_pattern = LexicalPattern.find(params[:id])
  end
end