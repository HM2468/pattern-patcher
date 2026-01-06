# app/controllers/concerns/processor_workspace_context.rb
module ProcessorWorkspaceContext
  extend ActiveSupport::Concern

  included do
    before_action :init_current_processo
  end

  private

  def init_current_processo
    @current_processor = LexemeProcessor.current_processor
  end
end