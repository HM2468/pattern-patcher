# app/models/scan_run.rb
class ScanRun < ApplicationRecord
  belongs_to :lexical_pattern, foreign_key: :pattern_id

  has_many :occurrences, dependent: :destroy

  STATUSES = %w[pending running finished failed].freeze
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :patterns_snapshot, presence: true, allow_nil: true

  scope :latest, -> { order(created_at: :desc) }
  scope :finished, -> { where(status: "finished") }

  before_validation :default_status, on: :create
  before_create :snapshot_pattern

  private

  def default_status
    self.status ||= "pending"
  end

  def snapshot_pattern
    self.patterns_snapshot ||= {
      pattern_id: lexical_pattern.id,
      name: lexical_pattern.name,
      pattern: lexical_pattern.pattern,
      language: lexical_pattern.language,
      pattern_type: lexical_pattern.pattern_type,
      priority: lexical_pattern.priority,
      enabled: lexical_pattern.enabled,
      captured_at: Time.current
    }.to_json
  end
end