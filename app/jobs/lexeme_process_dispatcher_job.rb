# frozen_string_literal: true
# app/jobs/lexeme_process_dispatcher_job.rb

class LexemeProcessDispatcherJob < ApplicationJob
  queue_as :lexeme_process_dispatcher

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

    unless %w[pending running].include?(job.status)
      Rails.logger&.info("[LexemeProcessDispatcherJob] skip dispatch due to status=#{job.status} job_id=#{job.id}")
      return
    end

    job.update!(status: "running") if job.status == "pending"
    total = Lexeme.pending.count
    job.init_progress!(total: total)
    lexemes = []
    Lexeme.pending
          .select(:id, :normalized_text, :metadata)
          .in_batches(of: 1000) do |relation|
      lexemes.concat(relation.to_a)
    end
    if total == 0
      LexemeProcessFinalizeJob.perform_later(job.id)
      return
    end

    # return Array<Array<Lexeme>>
    batches = job.batch_by_token(lexemes)
    # record batch count（flag of finalization）
    Rails.cache.write(job.batches_total_key, batches.size, expires_in: 2.days)
    # dispatch worker jobs（one batch one job）
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