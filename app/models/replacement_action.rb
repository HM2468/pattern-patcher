# app/models/replacement_action.rb
class ReplacementAction < ApplicationRecord
  belongs_to :occurrence
  belongs_to :repository_file

  DECISIONS = %w[apply skip].freeze
  STATUSES = %w[pending applied skipped rolled_back failed].freeze

  validates :decision, presence: true, inclusion: { in: DECISIONS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :base_file_sha, length: { is: 64 }, allow_nil: true

  before_validation :default_status, on: :create

  scope :latest, -> { order(created_at: :desc) }

  private

  def default_status
    self.status ||= "pending"
  end
end