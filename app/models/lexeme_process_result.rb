# frozen_string_literal: true

class LexemeProcessResult < ApplicationRecord
  belongs_to :lexeme_process_job
  belongs_to :lexeme

  attribute :metadata, :jsonb, default: {}
  attribute :output_json, :jsonb, default: {}

  validates :lexeme_process_job_id, presence: true
  validates :lexeme_id, presence: true
  validates :lexeme_id, uniqueness: { scope: :lexeme_process_job_id }

  # 常用查询
  scope :for_job, ->(job_id) { where(lexeme_process_job_id: job_id) }
  scope :for_lexeme, ->(lexeme_id) { where(lexeme_id: lexeme_id) }
  scope :with_output, -> { where.not(output_json: {}) }

  def translated_text
    output_json["translated_text"].to_s
  end

  def i18n_key
    output_json["i18n_key"].to_s
  end

  def locale
    output_json["locale"].to_s
  end

  # 约定：metadata 里如果有 error，认为失败
  def failed?
    metadata.is_a?(Hash) && metadata["error"].present?
  end

  def error_message
    metadata.is_a?(Hash) ? metadata["error"].to_s : ""
  end

  # 便捷写入：把 output_json/metadata merge 更新
  def merge_output!(output_json: nil, metadata: nil)
    h1 = (self.output_json || {}).deep_dup
    h2 = (self.metadata || {}).deep_dup
    h1.merge!(output_json) if output_json.is_a?(Hash)
    h2.merge!(metadata) if metadata.is_a?(Hash)
    update!(output_json: h1, metadata: h2)
  end
end