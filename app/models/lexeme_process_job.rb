# frozen_string_literal: true
# app/models/lexeme_process_job.rb
class LexemeProcessJob < ApplicationRecord
  belongs_to :lexeme_processor
  has_many :lexeme_process_results, dependent: :delete_all

  STATUSES = %w[pending running succeeded failed].freeze
  validates :status, inclusion: { in: STATUSES }, presence: true

  # entrypoint 示例：
  # - "LexemeProcessors::LocalizeRails"（推荐：全限定名）
  # - "LocalizeRails"（也支持：会自动补 LexemeProcessors::）
  def init_processor
    entry = lexeme_processor.entrypoint.to_s.strip
    raise ArgumentError, "entrypoint is blank" if entry.blank?

    klass_name =
      if entry.include?("::")
        entry
      else
        "LexemeProcessors::#{entry}"
      end

    klass = klass_name.constantize
    klass.new(
      config: lexeme_processor.default_config || {},
      processor: lexeme_processor,
      process_job: self
    )
  rescue NameError => e
    Rails.logger&.error("[LexemeProcessJob] processor not found: #{klass_name} (#{e.class}: #{e.message})")
    nil
  rescue => e
    Rails.logger&.error("[LexemeProcessJob] init_processor failed: #{e.class}: #{e.message}")
    nil
  end

  def progress_key
    "lexeme_process_jobs:progress:#{id}"
  end
end