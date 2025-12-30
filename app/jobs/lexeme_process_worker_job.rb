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

    return if %w[succeeded failed].include?(job.status)
    lexemes = Lexeme.where(id: lexeme_ids).select(:id, :normalized_text, :metadata).to_a
    if lexemes.empty?
      bump_batch_done!(job)
      try_finalize!(job)
      return
    end

    input = processor.build_input(lexemes)
    results = processor.run_process(lex_arr: input)
    processor.write_results!(results: results)
  rescue => e
    Rails.logger&.error(
      "[LexemeProcessWorkerJob] batch failed job_id=#{process_job_id} ids=#{lexeme_ids.take(20)} err=#{e.class}: #{e.message}"
    )
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