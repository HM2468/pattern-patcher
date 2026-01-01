# frozen_string_literal: true

class LexemeProcessResult < ApplicationRecord
  belongs_to :process_run
  belongs_to :lexeme

  attribute :metadata, :jsonb, default: {}
  attribute :output_json, :jsonb, default: {}

  validates :process_run_id, presence: true
  validates :lexeme_id, presence: true
  validates :lexeme_id, uniqueness: { scope: :process_run_id }

  scope :for_lexeme, ->(lexeme_id) { where(lexeme_id: lexeme_id) }
  scope :with_output, -> { where.not(output_json: {}) }
end