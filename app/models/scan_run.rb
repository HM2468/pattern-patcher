# frozen_string_literal: true

# app/models/scan_run.rb
class ScanRun < ApplicationRecord
  belongs_to :lexical_pattern
  belongs_to :repository_snapshot
  has_many :occurrences, dependent: :delete_all
  has_many :scan_run_files, dependent: :delete_all

  STATUSES   = %w[pending running finished failed finished_with_errors].freeze
  PHASES     = %w[preparing scanning].freeze
  SCAN_MODES = %w[line file].freeze
  CACHE_TTL = 1.day
  PROGRESS_COLOR = {
    "pending" => "bg-indigo-500",
    "running" => "bg-emerald-500",
    "finished" => "bg-emerald-500",
    "failed" => "bg-red-500",
    "finished_with_errors" => "bg-red-500"
  }

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :scan_mode, presence: true, inclusion: { in: SCAN_MODES }
  scope :latest,   -> { order(created_at: :desc) }
  scope :finished, -> { where(status: "finished") }
  before_validation :default_status, on: :create
  after_destroy :cleanup_lexemes

  # Single cache key for "latest progress" (phase is stored in payload)
  def progress_key
    "scan_runs:progress:#{id}"
  end

  # Schema: {phase,total,done,failed,(optional)error}
  def progress_payload(phase:, total:, done: 0, occ_count: 0, failed: 0, error: nil)
    payload = {
      phase: phase.to_s,
      total: total.to_i,
      done: done.to_i,
      occ_count: occ_count.to_i,
      failed: failed.to_i
    }
    payload[:error] = error.to_s if error.present?
    payload
  end

  # Persist/read progress (Rails.cache)
  def write_progress(payload, expires_in: CACHE_TTL)
    Rails.cache.write(progress_key, payload, expires_in: expires_in)
    ActionCable.server.broadcast(
      "scan_runs",
      { id: id, payload: payload }
    )
    true
  rescue => e
    Rails.logger&.warn("[ScanRun] cache write failed key=#{progress_key}: #{e.class}: #{e.message}")
    false
  end

  def read_progress
    Rails.cache.read(progress_key)
  rescue => e
    Rails.logger&.warn("[ScanRun] cache read failed key=#{progress_key}: #{e.class}: #{e.message}")
    nil
  end

  private

  def default_status
    self.status ||= "pending"
  end

  def cleanup_lexemes
    Lexeme.left_joins(:occurrences).where(occurrences: { id: nil }).delete_all
  end
end