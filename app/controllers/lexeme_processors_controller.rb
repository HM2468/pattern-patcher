class LexemeProcessorsController < ApplicationController
  before_action :set_lexeme_processor, only: %i[show edit update destroy]

  # GET /lexeme_processors or /lexeme_processors.json
  def index
    @lexeme_processors = LexemeProcessor.all
  end

  # GET /lexeme_processors/1 or /lexeme_processors/1.json
  def show; end

  # GET /lexeme_processors/new
  def new
    @lexeme_processor = LexemeProcessor.new(
      name: "Example Processor",
      key: "example_processor",
      entrypoint: "ExampleProcessor",
      default_config: {
        use_llm: true,
        llm_provider: "openai",
        llm_model: "gpt-4o",
        batch_token_limit: 1500,
        key_prefix: "gpt_trans",
      },
      output_schema: {
        processed_text: "string",
        i18n_key: "string",
        locale: "string",
      },
    )
  end

  # GET /lexeme_processors/1/edit
  def edit; end

  # POST /lexeme_processors or /lexeme_processors.json
  def create
    @lexeme_processor = LexemeProcessor.new(lexeme_processor_params)

    respond_to do |format|
      if @lexeme_processor.save
        format.html { redirect_to @lexeme_processor, notice: "Lexeme processor was successfully created." }
        format.json { render :show, status: :created, location: @lexeme_processor }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @lexeme_processor.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /lexeme_processors/1 or /lexeme_processors/1.json
  def update
    respond_to do |format|
      if @lexeme_processor.update(lexeme_processor_params)
        format.html do
          redirect_to @lexeme_processor, notice: "Lexeme processor was successfully updated.", status: :see_other
        end
        format.json { render :show, status: :ok, location: @lexeme_processor }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @lexeme_processor.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /lexeme_processors/1 or /lexeme_processors/1.json
  def destroy
    @lexeme_processor.destroy!

    respond_to do |format|
      format.html do
        redirect_to lexeme_processors_path, notice: "Lexeme processor was successfully destroyed.", status: :see_other
      end
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_lexeme_processor
    @lexeme_processor = LexemeProcessor.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def lexeme_processor_params
    params.expect(lexeme_processor: %i[name key entrypoint default_config output_schema enabled])
  end
end
