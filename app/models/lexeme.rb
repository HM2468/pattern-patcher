# app/models/lexeme.rb
class Lexeme < ApplicationRecord
  has_many :occurrences, dependent: :delete_all
  has_one :lexeme_process_result, dependent: :delete

  PROCESS_STATUS = %w[pending processed ignored failed].freeze
  FINGERPRINT_LENGTH = 16

  validates :source_text, presence: true
  validates :normalized_text, presence: true
  validates :fingerprint, presence: true, uniqueness: true
  validates :process_status, presence: true, inclusion: { in: PROCESS_STATUS }

  scope :ignored, -> { where(process_status: 'ignored') }
  scope :pending, -> { where(process_status: 'pending') }
  scope :processed, -> { where(process_status: 'processed') }
  scope :with_metadata, -> { where.not(metadata: {}) }
  class << self
    def sha_digest(text)
      raise ArgumentError, "text must be present" if text.blank?

      Digest::SHA256.hexdigest(text.to_s)[0, FINGERPRINT_LENGTH]
    end
  end
end