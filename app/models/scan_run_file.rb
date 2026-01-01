# frozen_string_literal: true

class ScanRunFile < ApplicationRecord
  belongs_to :scan_run
  belongs_to :repository_file

  validates :status, presence: true
  # 幂等保护（DB 层已有 unique index，这里是双保险）
  validates :repository_file_id,
            uniqueness: { scope: :scan_run_id }

  enum :status, {
    pending: "pending",
    scanning: "scanning",
    finished: "finished",
    failed: "failed",
    skipped: "skipped"
  }, default: :pending
end