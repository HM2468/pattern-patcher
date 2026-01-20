# app/models/occurrence.rb
class Occurrence < ApplicationRecord
  belongs_to :scan_run
  belongs_to :lexeme
  belongs_to :lexical_pattern
  belongs_to :repository_file

  has_one :occurrence_review

  enum :status, {
    unprocessed: "unprocessed",
    processed:   "processed",
    ignored:     "ignored"
  }, default: :unprocessed

  validates :line_at, numericality: { only_integer: true, greater_than: 0 }
  validates :line_char_start, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :line_char_end, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def match_range
    return nil if line_char_start.nil? || line_char_end.nil?
    line_char_start..line_char_end
  end

  def highlighted_deletion
    highlight_in_context(context.to_s, matched_text.to_s, css_class: "highlighted_deletion")
  end

  def highlighted_addition
    reviewed = occurrence_review
    return ERB::Util.html_escape(context.to_s) if reviewed.nil? || reviewed.rendered_code.blank?

    highlight_in_context(context.to_s, reviewed.rendered_code.to_s, css_class: "highlighted_addition")
  end

  private

  def highlight_in_context(raw_context, raw_inner, css_class:)
    raw = raw_context.to_s
    return ERB::Util.html_escape(raw) if raw.blank?
    return ERB::Util.html_escape(raw) if line_char_start.nil? || line_char_end.nil?

    # IMPORTANT: keep consistent with existing behavior where end is used as-is.
    # end is EXCLUSIVE
    s = line_char_start.to_i
    e = line_char_end.to_i
    return ERB::Util.html_escape(raw) if s.negative? || e < s || s > raw.length

    prefix = raw[0...s].to_s
    suffix = raw[e..].to_s

    safe_prefix = ERB::Util.html_escape(prefix)
    safe_suffix = ERB::Util.html_escape(suffix)
    safe_inner = ERB::Util.html_escape(raw_inner.to_s)

    safe_prefix + "<span class=\"#{css_class}\">#{safe_inner}</span>" + safe_suffix
  end
end