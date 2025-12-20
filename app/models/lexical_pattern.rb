# app/models/lexical_pattern.rb
class LexicalPattern < ApplicationRecord
  has_many :scan_runs, dependent: :restrict_with_error
  has_many :occurrences, dependent: :restrict_with_error

  PATTERN_TYPES = %w[code comment string_literal template].freeze

  validates :name, presence: true
  validates :pattern, presence: true
  validates :language, presence: true
  validates :pattern_type, presence: true, inclusion: { in: PATTERN_TYPES }
  validates :priority, numericality: { only_integer: true, in: 1..1000 }, presence: true
  validate :pattern_must_be_valid_regex

  scope :enabled, -> { where(enabled: true) }
  scope :by_priority, -> { order(priority: :asc, id: :asc) }

  def compiled_regex
    Regexp.new(pattern)
  end

  private

  # Require users to input regex literal strings: /pattern/flags
  # - Must start with / and have a closing /
  # - Allow flags (only i m x)
  # - Must compile successfully in Ruby
  # - Note: Pure literals (like "/abc/") are allowed
  def pattern_must_be_valid_regex
    raw = pattern.to_s.strip

    m = raw.match(%r{\A/((?:\\\/|[^/])*)/([a-zA-Z]*)\z})
    unless m
      errors.add(:pattern, "must be a Ruby regex literal like /abc/ or /abc/i")
      return
    end

    body  = m[1]
    flags = m[2]

    allowed_flags = %w[i m x]
    invalid = flags.chars.uniq - allowed_flags
    if invalid.any?
      errors.add(:pattern, "invalid regex flags: #{invalid.join(', ')} (allowed: #{allowed_flags.join})")
      return
    end

    options = 0
    options |= Regexp::IGNORECASE if flags.include?("i")
    options |= Regexp::MULTILINE  if flags.include?("m")
    options |= Regexp::EXTENDED   if flags.include?("x")

    Regexp.new(body, options)
  rescue RegexpError => e
    errors.add(:pattern, "invalid regex: #{e.message}")
  end
end