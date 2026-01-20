# app/models/lexical_pattern.rb
class LexicalPattern < ApplicationRecord
  has_many :scan_runs, dependent: :restrict_with_error
  has_many :occurrences, dependent: :restrict_with_error

  ALLOWED_FLAGS  = %w[i m x].freeze

  validates :name, presence: true
  validates :pattern, presence: true
  validates :language, presence: true
  validates :scan_mode, presence: true
  validate :pattern_must_be_valid_regex

  default_scope { where(deleted_at: nil) }
  scope :enabled_true, -> { where(enabled: true) }

  enum :scan_mode, {
    line_mode: "line_mode",
    file_mode: "file_mode"
  }, default: :line_mode

  # Ensure only one enabled pattern exists:
  # - If this record is saved with enabled=true, disable all others in the same transaction.
  before_save :ensure_single_enabled, if: :will_enable?

  class << self
    # Always returns the single enabled record (if any)
    def current_pattern
      enabled_true.first
    end
  end

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

  def will_enable?
    enabled? && (new_record? || will_save_change_to_enabled?)
  end

  # When enabling this record, disable all others.
  # Use update_all to avoid callbacks/validations and keep it fast.
  def ensure_single_enabled
    return unless enabled?

    self.class.where(enabled: true).where.not(id: id).update_all(enabled: false, updated_at: Time.current)
  end

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