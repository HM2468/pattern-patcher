# app/controllers/lexemes_controller.rb
class LexemesController < ApplicationController
  include ProcessorWorkspaceContext
  layout "processor_workspace", only: %i[index show]

  def index
    @status = params[:status].presence
    base = Lexeme.order(created_at: :desc)

    @lexemes =
      case @status
      when "pending"   then base.pending
      when "processed" then base.processed
      when "ignored"   then base.ignored
      when "failed"    then base.failed
      else
        base
      end.page(params[:page]).per(10)
  end

  def show; end
end