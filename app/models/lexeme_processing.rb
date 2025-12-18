# app/models/lexeme_processing.rb
class LexemeProcessing < ApplicationRecord
  belongs_to :lexeme

  PROCESS_TYPES = %w[translation normalization classification key_generation].freeze
  STATUSES = %w[pending succeeded failed].freeze

  validates :process_type, presence: true, inclusion: { in: PROCESS_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :lexeme_id, uniqueness: { scope: %i[process_type locale] }

  before_validation :default_status, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }

  private

  def default_status
    self.status ||= "pending"
  end
end