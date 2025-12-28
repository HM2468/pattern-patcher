# app/models/lexeme_processor.rb
class LexemeProcessor < ApplicationRecord
  has_many :lexeme_process_jobs, dependent: :delete_all

  validates :name, :key, :entrypoint, presence: true
  validates :key, uniqueness: true
  scope :enabled, -> { where(enabled: true) }
end