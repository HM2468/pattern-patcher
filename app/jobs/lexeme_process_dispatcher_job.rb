# frozen_string_literal: true
# app/jobs/lexeme_process_dispatcher_job.rb

class LexemeProcessDispatcherJob < ApplicationJob
  queue_as :lexeme_process_dispatcher

  # @param process_run_id [Integer]
  def perform(process_run_id)
    run = ProcessRun.find_by(id: process_run_id)
    return if run.nil?

    processor = run.init_processor
    unless processor
      Rails.logger&.error("[LexemeProcessDispatcherJob] init_processor returned nil run_id=#{run.id}")
      run.mark_failed!(reason: "init_processor_failed")
      return
    end

    unless %w[pending running].include?(run.status)
      Rails.logger&.info("[LexemeProcessDispatcherJob] skip dispatch due to status=#{run.status} run_id=#{run.id}")
      return
    end

    run.update!(status: "running", started_at: Time.current) if run.status == "pending"
    total = Lexeme.pending.count
    run.init_progress!(total: total)
    lexemes = []
    Lexeme.pending
          .select(:id, :normalized_text, :metadata)
          .in_batches(of: 1000) do |relation|
      lexemes.concat(relation.to_a)
    end
    if total == 0
      LexemeProcessFinalizeJob.perform_later(run.id)
      return
    end

    # return Array<Array<Lexeme>>
    batches = run.batch_by_token(lexemes)
    Rails.cache.increment(run.batches_total_key, batches.size)
    # dispatch worker runs（one batch one run）
    batches.each do |batch|
      ids = batch.map(&:id)
      LexemeProcessWorkerJob.perform_later(run.id, ids)
    end
  rescue => e
    Rails.logger&.error("[LexemeProcessDispatcherJob] failed run_id=#{process_run_id} err=#{e.class}: #{e.message}")
    run&.update!(status: "failed")
    raise
  end
end