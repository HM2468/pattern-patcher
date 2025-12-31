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

    total = Rails.cache.increment(run.total_count_key, 0)
    succ  = Rails.cache.increment(run.succeed_count_key, 0)
    failc = Rails.cache.increment(run.failed_count_key, 0)
    total_batches = Rails.cache.increment(run.batches_total_key, 0)
    done_batches  = Rails.cache.increment(run.batches_done_key, 0)
    finished_at   = Time.current
    processed = succ + failc

    if total_batches > 0 && done_batches < total_batches
      return
    end

    payload = {
      total: total,
      succeeded: succ,
      failed: failc,
      processed: processed,
      batches_total: total_batches,
      batches_done: done_batches
    }

    final_status =
      if total == 0
        "succeeded"
      elsif failc > 0
        "failed"
      else
        "succeeded"
      end

    run.update!(
      status: final_status,
      finished_at: Time.current,
      progress_persisted: payload
    )

    # DB 落库成功后广播最终结果（UI 以此为准）
    LexemeProcessors::ProgressBroadcaster.broadcast_final(run, payload: payload)
  rescue => e
    Rails.logger&.error("[LexemeProcessFinalizeJob] failed run_id=#{process_run_id} err=#{e.class}: #{e.message}")
    raise
  ensure
    release_lock(lock_key) if defined?(lock_key) && lock_key.present?
  end

  private

  # 说明：
  # - RedisCacheStore 支持 unless_exist: true，可用作锁
  # - 这里不使用 fetch，因为 fetch 会在 key 已存在时返回旧值，难以判定“是否抢到锁”
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