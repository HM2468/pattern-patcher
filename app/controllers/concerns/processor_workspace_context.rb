# app/controllers/concerns/processor_workspace_context.rb
module ProcessorWorkspaceContext
  extend ActiveSupport::Concern

  included do
    before_action :init_current_processor
    before_action :init_lexeme_count
    before_action :init_occ_rev_count
  end

  private

  def init_current_processor
    @current_processor = LexemeProcessor.current_processor
  end

  def init_lexeme_count
    @lexeme_count = Lexeme.count
  end

  def init_occ_rev_count
    @occ_rev_count = OccurrenceReview.count
  end
end