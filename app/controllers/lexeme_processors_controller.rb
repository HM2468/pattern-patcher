# app/controllers/lexeme_processors_controller.rb
class LexemeProcessorsController < ApplicationController
  include ProcessorWorkspaceContext
  layout "processor_workspace", only: %i[index new show edit update guide]
  before_action :set_lexeme_processor, only: %i[edit toggle_enabled update destroy]

  def index
    @lexeme_processors = LexemeProcessor
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(12)
  end

  def guide
  end

  def show
  end

  def new
    @lexeme_processor = LexemeProcessor.new
  end

  # New rule: at most one LexemeProcessor can be enabled at any time.
  def toggle_enabled
    page = params[:page].presence || 1
    LexemeProcessor.transaction do
      to_enabled = !@lexeme_processor.enabled?
      if to_enabled
        LexemeProcessor.where.not(id: @lexeme_processor.id).where(enabled: true).update_all(enabled: false)
        @lexeme_processor.update!(enabled: true)
      else
        @lexeme_processor.update!(enabled: false)
      end
    end
    # refresh sidebar & current page list
    @current_processor = LexemeProcessor.current_processor
    @lexeme_processors =
      LexemeProcessor
        .order(updated_at: :desc)
        .page(page)
        .per(12)
    respond_to do |format|
      format.turbo_stream do
        streams = []
        # 1) refresh all toggles shown on current page
        streams += @lexeme_processors.map do |p|
          turbo_stream.replace(
            view_context.dom_id(p, :enabled_toggle),
            partial: "lexeme_processors/enabled_toggle",
            locals: { lexeme_processor: p }
          )
        end
        # 2) refresh current processor card (left sidebar)
        streams << turbo_stream.replace(
          "current_processor",
          partial: "lexeme_processors/current_processor"
        )
        render turbo_stream: streams
      end
      format.html { redirect_to lexeme_processors_path(page: page) }
    end
  end

  def edit; end

  # POST /lexeme_processors
  def create
    @lexeme_processor = LexemeProcessor.new
    @lexeme_processor.assign_attributes(lexeme_processor_params)
    normalize_jsonb_params!(@lexeme_processor)
    return render :new, status: :unprocessable_content if @lexeme_processor.errors.any?

    if @lexeme_processor.save
      flash[:success] = "Lexeme processor was successfully created."
      redirect_to lexeme_processors_url, status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /lexeme_processors/:id
  def update
    @lexeme_processor.assign_attributes(lexeme_processor_params)
    normalize_jsonb_params!(@lexeme_processor)
    return render :edit, status: :unprocessable_content if @lexeme_processor.errors.any?

    if @lexeme_processor.save
      flash[:success] = "Lexeme processor was successfully updated."
      redirect_to lexeme_processors_url, status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    flash[:success] = "Lexeme processor was successfully destroyed."
    @lexeme_processor.destroy
    redirect_to lexeme_processors_url, status: :see_other
  end

  private

  def set_lexeme_processor
    @lexeme_processor = LexemeProcessor.find(params[:id])
  end

  def lexeme_processor_params
    params.require(:lexeme_processor).permit(
      :name, :key, :entrypoint, :enabled,
      :default_config, :output_schema
    )
  end

  # Only responsible for 'format layer validation + type conversion', all errors written to record.errors
  # Once errors.any? is true, it will render early in create/update, avoiding model validation
  def normalize_jsonb_params!(record)
    record.default_config = parse_required_json_object(
      record.default_config,
      field: :default_config,
      record: record,
      allow_empty_object: false,
    )

    record.output_schema = parse_required_json_object(
      record.output_schema,
      field: :output_schema,
      record: record,
      allow_empty_object: false,
    )
  end

  # - nil/blank => "cannot be blank"
  # - JSON.parse error => "invalid json format: ..."
  # - parsed not Hash => "must be a JSON object"
  # - {} => "cannot be empty" (if allow_empty_object: false)
  # 返回：Hash（成功）或 {}（失败时也返回 {}，但我们会提前 render，不会继续 save）
  def parse_required_json_object(raw, field:, record:, allow_empty_object:)
    if raw.is_a?(Hash)
      obj = raw
    else
      s = raw.to_s.strip
      if s.blank?
        record.errors.add(field, "cannot be blank")
        return {}
      end
      begin
        obj = JSON.parse(s)
      rescue JSON::ParserError => e
        record.errors.add(field, "invalid json format: #{e.message}")
        return {}
      end
    end

    unless obj.is_a?(Hash)
      record.errors.add(field, "must be a JSON object (e.g. {\"a\": 1})")
      return {}
    end
    obj = obj.deep_stringify_keys
    if !allow_empty_object && obj.empty?
      record.errors.add(field, "cannot be empty")
      return {}
    end
    obj
  end
end
