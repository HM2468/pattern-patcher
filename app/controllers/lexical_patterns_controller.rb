class LexicalPatternsController < ApplicationController
  include RepositoryWorkspaceContext
  layout "repository_workspace", only: %i[index new edit update create test]
  before_action :set_lexical_pattern, only: [:test, :run_test, :toggle_enabled, :edit, :update, :destroy]

  def index
    # Keep ordering predictable for operators:
    @lexical_patterns =
      LexicalPattern
        .page(params[:page])
        .per(10)
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
  def toggle_enabled
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