# frozen_string_literal: true

class ScanRunFile < ApplicationRecord
  belongs_to :scan_run
  belongs_to :repository_file

  STATUSES = %w[
    pending
    scanning
    finished
    failed
    skipped
  ].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }

  # 幂等保护（DB 层已有 unique index，这里是双保险）
  validates :repository_file_id,
            uniqueness: { scope: :scan_run_id }

  scope :pending,  -> { where(status: "pending") }
  scope :finished, -> { where(status: "finished") }
  scope :failed,   -> { where(status: "failed") }
end