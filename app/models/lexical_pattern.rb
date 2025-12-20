# app/models/lexical_pattern.rb
class LexicalPattern < ApplicationRecord
  has_many :scan_runs, dependent: :restrict_with_error
  has_many :occurrences, dependent: :restrict_with_error

  PATTERN_TYPES  = %w[code comment string_literal template].freeze
  ALLOWED_FLAGS  = %w[i m x].freeze
  PRIORITY_RANGE = (1..1000)

  validates :name, presence: true
  validates :pattern, presence: true
  validates :language, presence: true
  validates :pattern_type, presence: true, inclusion: { in: PATTERN_TYPES }
  validates :priority, numericality: { only_integer: true, in: PRIORITY_RANGE }, presence: true
  validate :pattern_must_be_valid_regex

  scope :enabled, -> { where(enabled: true) }
  scope :by_priority, -> { order(priority: :asc, id: :asc) }

  # Compile stored regex literal string (e.g. "/abc/i") to Ruby Regexp
  def compiled_regex
    body, options = parse_regex_literal!(pattern)
    Regexp.new(body, options)
  end

  # Scan text line-by-line (keeps your "single-line" scanning model)
  # Returns an array of matched strings (flattened if regex has capture groups)
  def scan(text)
    return [] if text.blank? || !text.is_a?(String)

    re = compiled_regex

    res = []
    text.each_line do |line|
      matches = line.scan(re)
      next if matches.empty?

      # scan returns:
      # - ["m1","m2"] when no capture groups
      # - [["g1","g2"], ...] when capture groups exist
      res.concat(matches.is_a?(Array) ? matches.flatten : [matches])
    end
    res
  rescue RegexpError
    # Should not happen because validation compiles successfully,
    # but keep it safe for runtime.
    []
  end

  private

  # Require users to input regex literal strings: /pattern/flags
  # - Must start with / and have a closing /
  # - Allow flags (only i m x)
  # - Must compile successfully in Ruby
  # - Note: Pure literals (like "/abc/") are allowed
  def pattern_must_be_valid_regex
    parse_regex_literal!(pattern)
    true
  rescue ArgumentError, RegexpError => e
    errors.add(:pattern, e.message)
  end

  # Parse "/.../flags" into [body, options]
  def parse_regex_literal!(raw)
    s = raw.to_s.strip

    m = s.match(%r{\A/((?:\\\/|[^/])*)/([a-zA-Z]*)\z})
    raise ArgumentError, "must be a Ruby regex literal like /abc/ or /abc/i" unless m

    body  = m[1]
    flags = m[2]

    invalid = flags.chars.uniq - ALLOWED_FLAGS
    if invalid.any?
      raise ArgumentError, "invalid regex flags: #{invalid.join(', ')} (allowed: #{ALLOWED_FLAGS.join})"
    end

    options = 0
    options |= Regexp::IGNORECASE if flags.include?("i")
    options |= Regexp::MULTILINE  if flags.include?("m")
    options |= Regexp::EXTENDED   if flags.include?("x")

    # Ensure compilable
    Regexp.new(body, options)

    [body, options]
  end
end