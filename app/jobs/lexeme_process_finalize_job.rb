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

    total = Rails.cache.read(run.total_count_key).to_i
    succ  = Rails.cache.read(run.succeed_count_key).to_i
    failc = Rails.cache.read(run.failed_count_key).to_i

    total_batches = Rails.cache.read(run.batches_total_key).to_i
    done_batches  = Rails.cache.read(run.batches_done_key).to_i

    started_at_ts = Rails.cache.read(run.started_at_key).to_i
    started_at    = started_at_ts > 0 ? Time.at(started_at_ts) : nil
    finished_at   = Time.current

    processed = succ + failc

    # 防止误触发：batch 未全部完成则不 finalize（让后续 worker 再触发）
    if total_batches > 0 && done_batches < total_batches
      return
    end

    payload = {
      total: total,
      succeeded: succ,
      failed: failc,
      processed: processed,
      batches_total: total_batches,
      batches_done: done_batches,
      started_at: started_at&.iso8601,
      finished_at: finished_at.iso8601,
      duration_seconds: started_at ? (finished_at - started_at).round(3) : nil
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