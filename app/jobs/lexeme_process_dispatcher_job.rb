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
      job.mark_failed!(reason: "init_processor_failed")
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
    job.init_progress!(total: total)

    if total == 0
      # 没有要处理的，直接 finalize
      LexemeProcessFinalizeJob.perform_later(job.id)
      return
    end

    # token 切批：返回 Array<Array<Lexeme>>
    batches = job.batch_by_token(lexemes)

    # 记录 batch 总数（用于完成判断）
    Rails.cache.write(job.batches_total_key, batches.size, expires_in: 2.days)

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
end