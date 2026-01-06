class LexicalPatternsController < ApplicationController
  include RepositoryWorkspaceContext
  layout "repository_workspace", only: %i[index new edit update create test]
  before_action :set_lexical_pattern, only: [:test, :run_test, :toggle_enabled, :edit, :update, :destroy]

  def index
    @lexical_patterns =
      LexicalPattern
        .order(updated_at: :desc)
        .page(params[:page])
        .per(12)
  end

  def new
    @lexical_pattern = LexicalPattern.new(enabled: false)
  end

  def create
    @lexical_pattern = LexicalPattern.new(lexical_pattern_params)

    if @lexical_pattern.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to lexical_patterns_path, notice: "Pattern created successfully." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @lexical_pattern.destroy!

    redirect_to lexical_patterns_path(page: params[:page])
  end

  # Toggle enabled via a tiny PATCH request (Turbo compatible)
  # New rule: at most one LexicalPattern can be enabled at any time.
  def toggle_enabled
    page = params[:page].presence || 1

    LexicalPattern.transaction do
      to_enabled = !@lexical_pattern.enabled?

      if to_enabled
        LexicalPattern.where.not(id: @lexical_pattern.id).where(enabled: true).update_all(enabled: false)
        @lexical_pattern.update!(enabled: true)
      else
        @lexical_pattern.update!(enabled: false)
      end
    end
    @current_pattern = LexicalPattern.current_pattern
    @lexical_patterns =
      LexicalPattern
        .order(updated_at: :desc)
        .page(page)
        .per(12)
    respond_to do |format|
      format.turbo_stream do
        streams = []
        streams += @lexical_patterns.map do |pattern|
          turbo_stream.replace(
            view_context.dom_id(pattern, :enabled_toggle),
            partial: "lexical_patterns/enabled_toggle",
            locals: { lexical_pattern: pattern }
          )
        end
        streams << turbo_stream.replace(
          "current_pattern",
          partial: "lexical_patterns/current_pattern"
        )
        render turbo_stream: streams
      end
      format.html { redirect_to lexical_patterns_path(page: page) }
    end
  end

  def update
    if @lexical_pattern.update(lexical_pattern_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to lexical_patterns_path, notice: "Pattern updated successfully." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def test
  end

  # POST /lexical_patterns/:id/test
  # params: { test_content: "..." }
  # returns: { st: [...] }
  def run_test
    content = params[:test_content].to_s
    raw = @lexical_pattern.scan(content)
    render json: { st: raw }
  rescue RegexpError => e
    render json: { st: [], error: "invalid regex: #{e.message}" }, status: :unprocessable_entity
  end

  def edit
  end

  def update
    if @lexical_pattern.update(lexical_pattern_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to lexical_patterns_path, notice: "Pattern updated successfully." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_lexical_pattern
    @lexical_pattern = LexicalPattern.find(params[:id])
  end

  def lexical_pattern_params
    params.require(:lexical_pattern).permit(:name, :pattern, :language, :scan_mode, :enabled)
  end
end