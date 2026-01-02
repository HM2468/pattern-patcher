class LexemesController < ApplicationController
  include LexemeWorkspaceSection

  def index
    @lexemes = Lexeme.order(created_at: :desc)
      .page(params[:page])
      .per(10)
  end

  def show; end
end
