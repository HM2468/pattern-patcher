# app/models/lexeme.rb
class Lexeme < ApplicationRecord
  has_many :occurrences
  has_one :lexeme_process_result

  validates :source_text, presence: true
  validates :normalized_text, presence: true
  validates :fingerprint, presence: true, uniqueness: true
  validates :process_status, presence: true
  scope :with_metadata, -> { where.not(metadata: {}) }

  enum :process_status, {
    pending: "pending",
    processed: "processed",
    ignored: "ignored",
    failed: "failed"
  }, default: :pending
  class << self
    def sha_digest(text)
      raise ArgumentError, "text must be present" if text.blank?

      Digest::SHA256.hexdigest(text.to_s)[0, 16]
    end
  end

  def metadata_pretty
    return '-' unless metadata.present?
    prettier_json(metadata)
  end
end