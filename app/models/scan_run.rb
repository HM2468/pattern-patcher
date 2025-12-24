# app/models/scan_run.rb
class ScanRun < ApplicationRecord
  belongs_to :lexical_pattern
  has_many :occurrences, dependent: :destroy
  has_many :repository_snapshots

  STATUSES = %w[pending running finished failed].freeze
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :latest, -> { order(created_at: :desc) }
  scope :finished, -> { where(status: "finished") }

  before_validation :default_status, on: :create

  private

  def default_status
    self.status ||= "pending"
  end
end