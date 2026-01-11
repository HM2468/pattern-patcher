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

  def highlighted_deletion
    highlight_in_context(context.to_s, matched_text.to_s, css_class: "highlighted_deletion")
  end

  def highlighted_addition
    reviewed = occurrence_review
    return context.to_s if reviewed.nil? || reviewed.rendered_code.blank?
    return context.to_s if line_char_start.nil? || line_char_end.nil?

    s = line_char_start.to_i
    e = line_char_end.to_i
    raw = context.to_s
    return raw if s.negative? || e < s || s > raw.length

    prefix = raw[0...s].to_s
    suffix = raw[e..].to_s

    safe_prefix = ERB::Util.html_escape(prefix)
    safe_suffix = ERB::Util.html_escape(suffix)
    safe_new = ERB::Util.html_escape(reviewed.rendered_code.to_s)

    safe_prefix + "<span class=\"highlighted_addition\">#{safe_new}</span>" + safe_suffix
  end

  private

  def highlight_in_context(raw_context, raw_matched, css_class:)
    raw = raw_context.to_s
    return ERB::Util.html_escape(raw) if raw.blank?
    return ERB::Util.html_escape(raw) if line_char_start.nil? || line_char_end.nil?

    s = line_char_start.to_i
    e = line_char_end.to_i
    return ERB::Util.html_escape(raw) if s.negative? || e < s || s > raw.length

    prefix = raw[0...s].to_s
    mid = raw_matched.to_s.presence || raw[s..e].to_s
    suffix = raw[e..].to_s

    safe_prefix = ERB::Util.html_escape(prefix)
    safe_mid = ERB::Util.html_escape(mid)
    safe_suffix = ERB::Util.html_escape(suffix)

    safe_prefix + "<span class=\"#{css_class}\">#{safe_mid}</span>" + safe_suffix
  end
end