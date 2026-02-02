# frozen_string_literal: true
# app/jobs/lexeme_process_finalize_job.rb
class LexemeProcessFinalizeJob < ApplicationJob
  queue_as :lexeme_process_dispatcher

  # @param process_run_id [Integer]
  def perform(process_run_id)
    run = ProcessRun.find_by(id: process_run_id)
    return if run.nil?
    return if %w[succeeded failed].include?(run.status)

    lock_key = run.finalize_lock_key
    locked = acquire_lock(lock_key, ttl: 5.minutes)
    return unless locked

    # payload:
    # {
    #   status: "done",
    #   total: 6407,
    #   succeeded: 6407,
    #   failed: 0,
    #   processed: 6407,
    #   percent: 100.0,
    #   batches_total: 38,
    #   batches_done: 38,
    #   occ_revc: 0
    #  }
    payload = run.build_progress_payload_from_cache
    return if payload[:batches_total] > 0 && payload[:batches_done] < payload[:batches_total]

    payload[:status] = payload[:failed] > 0 ? "failed" : "done"
    run.update!(
      status: payload[:status],
      finished_at: Time.current,
      progress_persisted: payload
    )
    run.broadcast_final(payload: payload)
  rescue => e
    Rails.logger&.error("[LexemeProcessFinalizeJob] failed run_id=#{process_run_id} err=#{e.class}: #{e.message}")
    raise
  ensure
    release_lock(lock_key) if defined?(lock_key) && lock_key.present?
  end

  private

  # Notes:
  # - RedisCacheStore supports `unless_exist: true`, which can be used as a lock
  # - We do not use `fetch` here because `fetch` returns the existing value
  #   when the key already exists, making it difficult to determine
  #   whether the lock was successfully acquired
  def acquire_lock(key, ttl:)
    Rails.cache.write(key, SecureRandom.hex(12), expires_in: ttl, unless_exist: true)
  rescue => e
    Rails.logger&.error("[LexemeProcessFinalizeJob] acquire_lock failed err=#{e.class}: #{e.message}")
    false
  end

  def release_lock(key)
    Rails.cache.delete(key)
  rescue => e
    Rails.logger&.error("[LexemeProcessFinalizeJob] release_lock failed err=#{e.class}: #{e.message}")
  end
end
