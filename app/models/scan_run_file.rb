# frozen_string_literal: true

class ScanRunFile < ApplicationRecord
  belongs_to :scan_run
  belongs_to :repository_file

  validates :status, presence: true
  # Idempotency protection (DB already has a unique index, this is just extra insurance)
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