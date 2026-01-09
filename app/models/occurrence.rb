# app/models/occurrence.rb
class Occurrence < ApplicationRecord
  belongs_to :scan_run
  belongs_to :lexeme
  belongs_to :lexical_pattern
  belongs_to :repository_file

  has_one :occurrence_review, dependent: :destroy

  enum :status, {
    unprocessed: "unprocessed",
    processed:   "processed",
    ignored:     "ignored",
  }, default: :unprocessed

  validates :line_at, numericality: { only_integer: true, greater_than: 0 }
  validates :line_char_start, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :line_char_end, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def match_range
    return nil if line_char_start.nil? || line_char_end.nil?
    line_char_start..line_char_end
  end

  def highlighted_origin_context
    highlighted = "<span class=\"ppmatchhi\">#{matched_text}</span>"
    context[0...line_char_start] + highlighted + context[(line_char_end + 1)..]
  end

  def replaced_text
    reviewed = occurrence_review
    return context if reviewed.nil? || reviewed.rendered_code.blank?
    return context if line_char_start.nil? || line_char_end.nil?

    context[0...line_char_start] + reviewed.rendered_code + context[(line_char_end + 1)..].to_s
  end
end