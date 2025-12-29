# app/controllers/lexeme_processors_controller.rb
class LexemeProcessorsController < ApplicationController
  before_action :set_lexeme_processor, only: %i[show edit update destroy]
  before_action :set_section

  def index
    case @section
    when "processors"
      @lexeme_processors = LexemeProcessor.order(created_at: :desc)

      # processors 为空：右侧直接渲染 new 表单（你已有 _form）
      if @lexeme_processors.blank?
        @lexeme_processor = LexemeProcessor.new
      end

    when "process_jobs"
      @lexeme_process_jobs =
        LexemeProcessJob
          .includes(:lexeme_processor)
          .order(created_at: :desc)

    when "lexemes"
      @lexemes =
        Lexeme
          .order(created_at: :desc)

    else
      # fallback
      @section = "processors"
      @lexeme_processors = LexemeProcessor.order(created_at: :desc)
      @lexeme_processor = LexemeProcessor.new if @lexeme_processors.blank?
    end
  end

  def new
    @lexeme_processor = LexemeProcessor.new
  end

  def edit; end

  # POST /lexeme_processors
  def create
    @lexeme_processor = LexemeProcessor.new
    @lexeme_processor.assign_attributes(lexeme_processor_params)
    normalize_jsonb_params!(@lexeme_processor)
    return render :new, status: :unprocessable_content if @lexeme_processor.errors.any?

    if @lexeme_processor.save
      redirect_to @lexeme_processor, notice: "Lexeme processor was successfully created."
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
      redirect_to @lexeme_processor, notice: "Lexeme processor was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @lexeme_processor.destroy
    redirect_to lexeme_processors_url, notice: "Lexeme processor was successfully destroyed.", status: :see_other
  end

  private

  # processors | process_jobs | lexemes
  def set_section
    @section = params[:section].presence || "processors"
  end

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
