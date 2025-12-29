class LexemesController < ApplicationController
  include LexemeWorkspaceSection

  def index
    @lexemes = Lexeme.order(created_at: :desc)
  end

  def show
  end
end
