# app/models/lexeme_process_job.rb
class LexemeProcessJob < ApplicationRecord
  belongs_to :lexeme_processor
  has_many :lexeme_process_results, dependent: :delete_all

  STATUSES = %w[pending running succeeded failed].freeze
  validates :status, inclusion: { in: STATUSES }

  def write_progress(payload)
    update!(progress_persisted: payload)
  rescue => e
    Rails.logger&.warn("[LexemeProcessJob] write_progress failed: #{e.class}: #{e.message}")
    false
  end

  def increment_progress!(done:, failed:, error: nil)
    p = (progress_persisted || {}).deep_dup
    p["phase"] ||= "processing"
    p["total"] ||= 0
    p["done"]  = p["done"].to_i + done.to_i
    p["failed"] = p["failed"].to_i + failed.to_i
    p["error"] = error.to_s if error.present?
    update!(progress_persisted: p)
  end

  # 当所有目标 lexemes 都不再 pending/processing 时，认为 job 可结束
  def try_finalize!
    return unless status == "running"

    total = progress_persisted["total"].to_i
    done  = progress_persisted["done"].to_i
    failed = progress_persisted["failed"].to_i
    return if total <= 0
    return if (done + failed) < total

    final_status = failed.positive? ? "failed" : "succeeded"
    update!(status: final_status, finished_at: Time.current)
  end
end