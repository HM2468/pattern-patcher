# frozen_string_literal: true

# app/helpers/lexemes_helper.rb
module LexemesHelper

  def lexeme_status_badge_class(lexeme)
    case lexeme.process_status.to_s
    when "processed"
      "bg-emerald-50 text-emerald-700 border-emerald-200"
    when "unprocessed"
      "bg-amber-50 text-amber-700 border-amber-200"
    when "ignored"
      "bg-gray-100 text-gray-700 border-gray-200"
    else
      "bg-indigo-50 text-indigo-700 border-indigo-200"
    end
  end
end
