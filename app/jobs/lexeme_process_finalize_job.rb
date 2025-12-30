# frozen_string_literal: true
# app/jobs/lexeme_process_finalize_job.rb

class LexemeProcessFinalizeJob < ApplicationJob
  queue_as :lexeme_process_dispatcher

  # @param process_job_id [Integer]
  def perform(process_job_id)
    job = LexemeProcessJob.find_by(id: process_job_id)
    return if job.nil?
    return if %w[succeeded failed].include?(job.status)

    # 分布式锁：确保只有一个 finalize 在跑
    lock_key = job.finalize_lock_key
    locked = acquire_lock(lock_key, ttl: 5.minutes)
    return unless locked

    total = Rails.cache.read(job.total_count_key).to_i
    succ  = Rails.cache.read(job.succeed_count_key).to_i
    fail  = Rails.cache.read(job.failed_count_key).to_i

    total_batches = Rails.cache.read(job.batches_total_key).to_i
    done_batches  = Rails.cache.read(job.batches_done_key).to_i

    started_at_ts = Rails.cache.read(job.started_at_key).to_i
    started_at    = started_at_ts > 0 ? Time.at(started_at_ts) : nil
    finished_at   = Time.current

    processed = succ + fail

    # 如果还有 batch 没完成，不 finalize（防止误触发）
    if total_batches > 0 && done_batches < total_batches
      return
    end

    payload = {
      total: total,
      succeeded: succ,
      failed: fail,
      processed: processed,
      batches_total: total_batches,
      batches_done: done_batches,
      started_at: started_at&.iso8601,
      finished_at: finished_at.iso8601,
      duration_seconds: started_at ? (finished_at - started_at).round(3) : nil
    }

    # 根据失败情况决定最终状态（你也可以用更严格规则）
    final_status =
      if total == 0
        "succeeded"
      elsif fail > 0
        "failed"
      else
        "succeeded"
      end

    job.update!(
      status: final_status,
      progress_persisted: payload
    )
  rescue => e
    Rails.logger&.error("[LexemeProcessFinalizeJob] failed job_id=#{process_job_id} err=#{e.class}: #{e.message}")
    # finalize 出错时不强行改 failed，避免误伤；让它重试
    raise
  ensure
    release_lock(lock_key) if defined?(lock_key) && lock_key.present?
  end

  private

  # 下面这套 lock 实现只依赖 Rails.cache（Redis 后端）
  # 如果你的 Rails.cache 不支持 write NX（不同 store 行为差异），可以改成直接用 Redis 客户端 set(nx: true)
  def acquire_lock(key, ttl:)
    # 使用 fetch 实现“抢占式”锁：已经存在就不执行 block
    Rails.cache.fetch(key, expires_in: ttl, race_condition_ttl: 0) { SecureRandom.hex(12) }.present?
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