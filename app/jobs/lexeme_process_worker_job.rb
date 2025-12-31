# frozen_string_literal: true
# app/jobs/lexeme_process_worker_job.rb

class LexemeProcessWorkerJob < ApplicationJob
  queue_as :lexeme_process_worker

  # @param process_run_id [Integer]
  # @param lexeme_ids [Array<Integer>]
  def perform(process_run_id, lexeme_ids)
    run = ProcessRun.find_by(id: process_run_id)
    return if run.nil?

    # 已经结束就不做（避免 finalize 后残余任务继续写）
    return if %w[succeeded failed].include?(run.status)

    processor = run.init_processor
    unless processor
      Rails.logger&.error("[LexemeProcessWorkerJob] init_processor returned nil run_id=#{run.id}")
      # 该 batch 视为失败（尽力累加失败数）
      Rails.cache.increment(run.failed_count_key, lexeme_ids.size) rescue nil
      return
    end

    lexemes = Lexeme.where(id: lexeme_ids).select(:id, :normalized_text, :metadata).to_a
    return if lexemes.empty?

    input = processor.build_input(lexemes)
    results = processor.run_process(lex_arr: input)
    processor.write_results!(results: results)
  rescue => e
    Rails.logger&.error(
      "[LexemeProcessWorkerJob] batch failed run_id=#{process_run_id} ids=#{lexeme_ids.take(20)} err=#{e.class}: #{e.message}"
    )

    # run 已经查询过，可能在 rescue 时为 nil（极端情况）
    if defined?(run) && run
      begin
        Lexeme.where(id: lexeme_ids).update_all(process_status: "failed", updated_at: Time.current)
      rescue => e2
        Rails.logger&.error("[LexemeProcessWorkerJob] mark failed error err=#{e2.class}: #{e2.message}")
      end

      begin
        Rails.cache.increment(run.failed_count_key, lexeme_ids.size)
      rescue => e3
        Rails.logger&.error("[LexemeProcessWorkerJob] failed counter incr error err=#{e3.class}: #{e3.message}")
      end
    end
  ensure
    # 统一在 ensure 里推进 batches_done + 广播进度 + 尝试 finalize
    if defined?(run) && run
      bump_batch_done!(run)
      LexemeProcessors::ProgressBroadcaster.broadcast_progress_throttled(run)
      try_finalize!(run)
    end
  end

  private

  def bump_batch_done!(run)
    Rails.cache.increment(run.batches_done_key, 1)
  rescue => e
    Rails.logger&.error("[LexemeProcessWorkerJob] bump_batch_done! err=#{e.class}: #{e.message}")
  end

  def try_finalize!(run)
    total_batches = Rails.cache.increment(run.batches_total_key, 0)
    done_batches  = Rails.cache.increment(run.batches_done_key, 0)

    return if total_batches <= 0
    return unless done_batches >= total_batches

    # 触发 finalize（finalize 内部有锁，worker 可多次触发）
    LexemeProcessFinalizeJob.perform_later(run.id)
  rescue => e
    Rails.logger&.error("[LexemeProcessWorkerJob] try_finalize! err=#{e.class}: #{e.message}")
  end
end