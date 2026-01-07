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
    @pending_lc = Lexeme.pending.count
    @processed_lc = Lexeme.processed.count
  end

  def init_occ_rev_count
    @pending_occ_rev = OccurrenceReview.pending.count
    @reviewed_occ_rev = OccurrenceReview.reviewed.count
  end
end