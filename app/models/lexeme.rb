# app/models/lexeme.rb
class Lexeme < ApplicationRecord
  has_many :occurrences, dependent: :restrict_with_error
  has_many :lexeme_processings, dependent: :destroy
  has_many :replacement_targets, dependent: :destroy

  validates :source_text, presence: true
  validates :normalized_text, presence: true
  validates :fingerprint, presence: true, uniqueness: true
  validates :locale, presence: true

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