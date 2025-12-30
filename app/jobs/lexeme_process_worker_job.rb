# frozen_string_literal: true
# app/jobs/lexeme_process_worker_job.rb

class LexemeProcessWorkerJob < ApplicationJob
  queue_as :lexeme_process_worker

  # @param process_job_id [Integer]
  # @param lexeme_ids [Array<Integer>]
  def perform(process_job_id, lexeme_ids)
    job = LexemeProcessJob.find_by(id: process_job_id)
    return if job.nil?

    processor = job.init_processor
    unless processor
      Rails.logger&.error("[LexemeProcessWorkerJob] init_processor returned nil job_id=#{job.id}")
      # 这里不直接 fail whole job；该 batch 视为失败
      Rails.cache.increment(job.failed_count_key, lexeme_ids.size) rescue nil
      bump_batch_done!(job)
      try_finalize!(job)
      return
    end

    # 如果 job 已经收敛结束，就不再处理（避免 finalize 后还有残余 job 执行）
    return if %w[succeeded failed].include?(job.status)

    # 取 lexemes（只取必要字段，避免大对象）
    lexemes = Lexeme.where(id: lexeme_ids).select(:id, :normalized_text, :metadata).to_a

    # 注意：lexeme_ids 可能有部分不存在（被删除等），以实际取到的为准
    if lexemes.empty?
      bump_batch_done!(job)
      try_finalize!(job)
      return
    end

    input = processor.build_input(lexemes)
    results = processor.run_process(lex_arr: input)

    # write_results! 内部已经：
    # - upsert_all 结果
    # - update lexeme status processed/failed（在异常分支）
    # - increment succeed/failed counters（原子）
    processor.write_results!(results: results)
  rescue => e
    Rails.logger&.error(
      "[LexemeProcessWorkerJob] batch failed job_id=#{process_job_id} ids=#{lexeme_ids.take(20)} err=#{e.class}: #{e.message}"
    )

    # 如果 run_process 或其他环节抛异常，这一整批计为失败（尽力而为标记）
    begin
      Lexeme.where(id: lexeme_ids).update_all(process_status: "failed", updated_at: Time.current)
    rescue => e2
      Rails.logger&.error("[LexemeProcessWorkerJob] mark failed error err=#{e2.class}: #{e2.message}")
    end

    begin
      Rails.cache.increment(job.failed_count_key, lexeme_ids.size)
    rescue => e3
      Rails.logger&.error("[LexemeProcessWorkerJob] failed counter incr error err=#{e3.class}: #{e3.message}")
    end
  ensure
    # 无论成功失败，都要标记 batch done，并尝试 finalize
    bump_batch_done!(job) if job
    try_finalize!(job) if job
  end

  private

  def bump_batch_done!(job)
    Rails.cache.increment(job.batches_done_key, 1)
  rescue => e
    Rails.logger&.error("[LexemeProcessWorkerJob] bump_batch_done! err=#{e.class}: #{e.message}")
  end

  def try_finalize!(job)
    total_batches = Rails.cache.read(job.batches_total_key).to_i
    done_batches  = Rails.cache.read(job.batches_done_key).to_i

    return if total_batches <= 0
    return unless done_batches >= total_batches

    # 触发 finalize（由 finalize job 做幂等锁，worker 这里可以多次触发无所谓）
    LexemeProcessFinalizeJob.perform_later(job.id)
  rescue => e
    Rails.logger&.error("[LexemeProcessWorkerJob] try_finalize! err=#{e.class}: #{e.message}")
  end
end