# app/models/lexeme.rb
class Lexeme < ApplicationRecord
  has_many :occurrences, dependent: :delete_all

  validates :source_text, presence: true
  validates :normalized_text, presence: true
  validates :fingerprint, presence: true, uniqueness: true

  scope :unprocessed, -> { where(processed_at: nil) }
  scope :processed, -> { where.not(processed_at: nil) }
  FINGERPRINT_LENGTH = 16
  class << self
    def sha_digest(text)
      raise ArgumentError, "text must be present" if text.blank?

      Digest::SHA256.hexdigest(text.to_s)[0, FINGERPRINT_LENGTH]
    end
  end
end