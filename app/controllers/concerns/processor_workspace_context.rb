# app/controllers/concerns/processor_workspace_context.rb
module ProcessorWorkspaceContext
  extend ActiveSupport::Concern

  included do
    before_action :prepare_processor_workspace
  end

  private

  def prepare_processor_workspace
    @current_processor = LexemeProcessor.current_processor
    if @current_processor
      @process_run_count = @current_processor.process_runs.count
    else
      0
    end
  end
end