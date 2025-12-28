# frozen_string_literal: true
# app/models/lexeme_processor.rb
class LexemeProcessor < ApplicationRecord
  has_many :lexeme_process_jobs, dependent: :delete_all

  validates :name, :key, :entrypoint, presence: true
  validates :key, uniqueness: true
  validate :output_schema_must_be_valid

  scope :enabled, -> { where(enabled: true) }

  # 可以按需要扩展
  ALLOWED_SCHEMA_TYPES = %w[
    string integer number boolean object array
  ].freeze

  private

  def output_schema_must_be_valid
    schema = output_schema
    if schema.nil?
      errors.add(:output_schema, "must be a Hash, got nil")
      return
    end
    unless schema.is_a?(Hash)
      errors.add(:output_schema, "must be a Hash, got #{schema.class}")
      return
    end
    if schema.empty?
      errors.add(:output_schema, "cannot be empty")
      return
    end
    if schema.size > 50
      errors.add(:output_schema, "is too large (max 50 keys)")
      return
    end
    schema.each do |k, v|
      unless k.is_a?(String) && k.present?
        errors.add(:output_schema, "key must be a non-empty String, got #{k.inspect} (#{k.class})")
        next
      end
      unless v.is_a?(String) && v.present?
        errors.add(:output_schema, "type for #{k.inspect} must be a non-empty String, got #{v.inspect} (#{v.class})")
        next
      end
      unless ALLOWED_SCHEMA_TYPES.include?(v)
        errors.add(:output_schema, "type for #{k.inspect} must be one of #{ALLOWED_SCHEMA_TYPES.join(', ')}, got #{v.inspect}")
      end
    end
  end
end