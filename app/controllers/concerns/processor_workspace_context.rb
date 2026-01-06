# app/controllers/concerns/processor_workspace_context.rb
module ProcessorWorkspaceContext
  extend ActiveSupport::Concern

  included do
    before_action :prepare_processor_workspace
  end

  private

  def prepare_processor_workspace
    # 1) Left sidebar list (1 query)
    @processors  = LexemeProcessor.order(created_at: :desc).to_a
    @dropdown_list = @processors.map { |p| { id: p.id, name: p.name } }

    # IMPORTANT:
    # params[:id] means different things in different controllers.
    # - lexeme_processors/:id      => processor id
    # - process_runs/:id/*         => process_run id (NOT repo id)
    # Only treat params[:id] as processor_id when we are in LexemeProcessorsController.
    processor_id_from_id_param =
      controller_name == "lexeme_processors" ? params[:id].presence : nil

    # 2) Selected processor id (don't override controller's @processor)
    @selected_id =
      params[:processor_id].presence ||
      processor_id_from_id_param ||
      @processor&.id ||
      @processors.first&.id

    # 3) Workspace selected processor object: prioritize controller's @processor, then find from list (0 query)
    @selected_processor =
      if defined?(@processor) && @processor&.id.to_s == @selected_id.to_s
        @processor
      else
        @processors.find { |r| r.id == @selected_id.to_i }
      end
  end
end