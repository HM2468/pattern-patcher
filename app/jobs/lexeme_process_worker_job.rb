# frozen_string_literal: true
# app/jobs/lexeme_process_worker_job.rb

class LexemeProcessWorkerJob < ApplicationJob
  queue_as :lexeme_process_worker

  # @param process_run_id [Integer]
  # @param lexeme_ids [Array<Integer>]
  def perform(process_run_id, lexeme_ids)
    run = ProcessRun.find_by(id: process_run_id)
    return if run.nil?

    # Do nothing if already finished (avoid residual jobs writing after finalize)
    return if %w[succeeded failed].include?(run.status)

    processor = run.init_processor
    unless processor
      Rails.logger&.error("[LexemeProcessWorkerJob] init_processor returned nil run_id=#{run.id}")
      # Treat this batch as failed (best-effort failure count increment)
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

    # `run` was already queried, but it may be nil in rescue (edge cases)
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
    # Advance batches_done + broadcast progress + attempt finalize in ensure
    if defined?(run) && run
      bump_batch_done!(run)
      run.broadcast_progress_throttled
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

    # Trigger finalize (finalize has an internal lock; workers may trigger multiple times)
    LexemeProcessFinalizeJob.perform_later(run.id)
  rescue => e
    Rails.logger&.error("[LexemeProcessWorkerJob] try_finalize! err=#{e.class}: #{e.message}")
  end
end