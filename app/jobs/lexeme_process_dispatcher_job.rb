# frozen_string_literal: true
# app/jobs/lexeme_process_dispatcher_job.rb

class LexemeProcessDispatcherJob < ApplicationJob
  queue_as :lexeme_process_dispatcher

  # 你可以按需要调整批次大小（以 token batch 为主，这里仅作为 safety）
  DEFAULT_DB_FETCH_BATCH = 1_000

  # @param process_job_id [Integer]
  def perform(process_job_id)
    job = LexemeProcessJob.find_by(id: process_job_id)
    return if job.nil?

    processor = job.init_processor
    unless processor
      Rails.logger&.error("[LexemeProcessDispatcherJob] init_processor returned nil job_id=#{job.id}")
      mark_job_failed!(job, reason: "init_processor_failed")
      return
    end

    # 只允许 pending/running 的 job 继续调度（避免重复调度）
    unless %w[pending running].include?(job.status)
      Rails.logger&.info("[LexemeProcessDispatcherJob] skip dispatch due to status=#{job.status} job_id=#{job.id}")
      return
    end

    job.update!(status: "running") if job.status == "pending"

    # 读取 pending lexemes（尽量只取必要字段）
    lexemes = []
    Lexeme.pending
          .select(:id, :normalized_text, :metadata)
          .in_batches(of: DEFAULT_DB_FETCH_BATCH) do |relation|
      lexemes.concat(relation.to_a)
    end

    total = lexemes.size

    # 初始化进度（幂等写：如果重复调度，尽量不破坏已有计数）
    init_progress!(job, total: total)

    if total == 0
      # 没有要处理的，直接 finalize
      LexemeProcessFinalizeJob.perform_later(job.id)
      return
    end

    # token 切批：返回 Array<Array<Lexeme>>
    batches = job.batch_by_token(lexemes)

    # 记录 batch 总数（用于完成判断）
    Rails.cache.write(batches_total_key(job), batches.size, expires_in: 2.days)

    # 投递 worker jobs（每个 batch 一个 job）
    batches.each do |batch|
      ids = batch.map(&:id)
      LexemeProcessWorkerJob.perform_later(job.id, ids)
    end
  rescue => e
    Rails.logger&.error("[LexemeProcessDispatcherJob] failed job_id=#{process_job_id} err=#{e.class}: #{e.message}")
    job&.update!(status: "failed")
    raise
  end

  private

  def init_progress!(job, total:)
    # total：只在不存在时写，避免重复调度覆盖
    Rails.cache.write(job.total_count_key, total, expires_in: 2.days) unless Rails.cache.exist?(job.total_count_key)

    # succeeded/failed：不存在则初始化为 0
    Rails.cache.write(job.succeed_count_key, 0, expires_in: 2.days) unless Rails.cache.exist?(job.succeed_count_key)
    Rails.cache.write(job.failed_count_key, 0, expires_in: 2.days)  unless Rails.cache.exist?(job.failed_count_key)

    # batches_done 初始化
    Rails.cache.write(batches_done_key(job), 0, expires_in: 2.days) unless Rails.cache.exist?(batches_done_key(job))

    # 可选：记录开始时间（便于 finalize 输出）
    Rails.cache.write(started_at_key(job), Time.current.to_i, expires_in: 2.days) unless Rails.cache.exist?(started_at_key(job))
  end

  def mark_job_failed!(job, reason:)
    job.update!(
      status: "failed",
      progress_persisted: {
        reason: reason,
        failed_at: Time.current.iso8601
      }
    )
  rescue => e
    Rails.logger&.error("[LexemeProcessDispatcherJob] mark_job_failed! error job_id=#{job.id} err=#{e.class}: #{e.message}")
  end

  def batches_total_key(job)
    "#{job.progress_namespace}:batches_total"
  end

  def batches_done_key(job)
    "#{job.progress_namespace}:batches_done"
  end

  def started_at_key(job)
    "#{job.progress_namespace}:started_at"
  end
end