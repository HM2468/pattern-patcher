# frozen_string_literal: true

# app/models/scan_run.rb
class ScanRun < ApplicationRecord
  belongs_to :lexical_pattern
  belongs_to :repository_snapshot
  has_many :occurrences, dependent: :destroy
  has_many :scan_run_files, dependent: :delete_all

  STATUSES = %w[pending running finished failed finished_with_errors].freeze
  PHASES   = %w[building_files scanning_files].freeze
  MODE  = %w[line file].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :mode, presence: true, inclusion: { in: MODE }

  scope :latest,   -> { order(created_at: :desc) }
  scope :finished, -> { where(status: "finished") }

  before_validation :default_status, on: :create

  CACHE_TTL = 1.day


  # Cache keys (single source of truth)
  def persisting_progress_key
    "scan_runs:persisting_progress:#{id}"
  end

  def scanning_progress_key
    "scan_runs:scanning_progress:#{id}"
  end


  # Payload builders (single source of truth)
  # Unified schema: {phase,status,total,done,failed,(optional)error}
  def persisting_payload(status:, total:, done: 0, failed: 0, phase: PHASES[0], error: nil)
    base_progress_payload(
      phase: phase,
      status: status,
      total: total,
      done: done,
      failed: failed,
      error: error
    )
  end

  def scanning_payload(status:, total:, done:, failed:, phase: PHASES[1], error: nil)
    base_progress_payload(
      phase: phase,
      status: status,
      total: total,
      done: done,
      failed: failed,
      error: error
    )
  end


  # Persisting phase progress
  def write_persisting_progress(payload, expires_in: CACHE_TTL)
    write_progress_cache(persisting_progress_key, payload, expires_in: expires_in)
  end

  def read_persisting_progress
    read_progress_cache(persisting_progress_key)
  end

  # Scanning phase progress
  def write_scanning_progress(payload, expires_in: CACHE_TTL)
    write_progress_cache(scanning_progress_key, payload, expires_in: expires_in)
  end

  def read_scanning_progress
    read_progress_cache(scanning_progress_key)
  end


  # Low-level cache helpers (Rails.cache)
  def write_progress_cache(key, payload, expires_in: CACHE_TTL)
    Rails.cache.write(key, payload, expires_in: expires_in)
    true
  rescue => e
    Rails.logger&.warn("[ScanRun] cache write failed key=#{key}: #{e.class}: #{e.message}")
    false
  end

  def read_progress_cache(key)
    Rails.cache.read(key)
  rescue => e
    Rails.logger&.warn("[ScanRun] cache read failed key=#{key}: #{e.class}: #{e.message}")
    nil
  end

  private

  def default_status
    self.status ||= "pending"
  end

  # Unified schema across all progress payloads.
  def base_progress_payload(phase:, status:, total:, done:, failed:, error: nil)
    payload = {
      phase: phase.to_s,
      status: status.to_s,
      total: total.to_i,
      done: done.to_i,
      failed: failed.to_i
    }

    payload[:error] = error.to_s if error.present?
    payload
  end
end