# app/models/occurrence.rb
class Occurrence < ApplicationRecord
  belongs_to :scan_run
  belongs_to :lexeme
  belongs_to :lexical_pattern
  belongs_to :repository_file, foreign_key: :file_id

  has_many :replacement_actions, dependent: :destroy

  STATUSES = %w[unreviewed approved ignored replaced].freeze
  validates :status, presence: true, inclusion: { in: STATUSES }

  validates :line_at, numericality: { only_integer: true, greater_than: 0 }
  validates :idx_start, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :idx_end, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  validate :idx_range_valid

  scope :unreviewed, -> { where(status: "unreviewed") }
  scope :by_location, -> { order(file_id: :asc, line_at: :asc, idx_start: :asc) }

  before_validation :default_status, on: :create

  def match_range
    return nil if idx_start.nil? || idx_end.nil?
    idx_start..idx_end
  end

  private

  def default_status
    self.status ||= "unreviewed"
  end

  def idx_range_valid
    return if idx_start.nil? || idx_end.nil?
    errors.add(:idx_end, "must be >= idx_start") if idx_end < idx_start
  end
end