# app/models/lexical_pattern.rb
class LexicalPattern < ApplicationRecord
  has_many :scan_runs, dependent: :restrict_with_error
  has_many :occurrences, dependent: :restrict_with_error

  PATTERN_TYPES = %w[code comment string_literal template].freeze

  validates :name, presence: true
  validates :pattern, presence: true
  validates :language, presence: true
  validates :pattern_type, presence: true, inclusion: { in: PATTERN_TYPES }
  validates :priority, numericality: { only_integer: true }, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :by_priority, -> { order(priority: :asc, id: :asc) }

  validate :pattern_must_be_valid_regex

  def compiled_regex
    Regexp.new(pattern)
  end

  private

  def pattern_must_be_valid_regex
    Regexp.new(pattern)
  rescue RegexpError => e
    errors.add(:pattern, "invalid regex: #{e.message}")
  end
end