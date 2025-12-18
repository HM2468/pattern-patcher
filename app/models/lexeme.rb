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

  before_validation :normalize_and_fingerprint, on: :create

  private

  def normalize_and_fingerprint
    self.normalized_text ||= source_text.to_s.strip
    self.fingerprint ||= Digest::SHA256.hexdigest(normalized_text)
  end
end