# app/jobs/lexeme_process_enqueue_job.rb
class LexemeProcessEnqueueJob < ApplicationJob
  queue_as :lexeme_process_control

  def perform(lexeme_process_job_id:, batch_size:, config:, relation_sql:)
    job = LexemeProcessJob.find(lexeme_process_job_id)
    processor = job.lexeme_processor

    job.update!(status: "running", started_at: (job.started_at || Time.current))

    # 恢复 relation：只取 pending 的
    ids = Lexeme
      .from("(#{relation_sql}) lexeme_ids")
      .joins("JOIN lexemes ON lexemes.id = lexeme_ids.id")
      .where(lexemes: { process_status: "pending" })
      .order("lexemes.id ASC")
      .pluck("lexemes.id")

    job.write_progress(processor.progress_payload(
      phase: "enqueue",
      total: ids.size,
      done: 0,
      failed: 0
    ))

    ids.each_slice(batch_size) do |slice|
      LexemeProcessBatchJob.perform_later(
        lexeme_process_job_id: job.id,
        lexeme_ids: slice,
        config: config
      )
    end

    # enqueue 阶段结束：后续由 batch job 更新 done/failed
    job.write_progress(processor.progress_payload(
      phase: "processing",
      total: ids.size,
      done: 0,
      failed: 0
    ))
  rescue => e
    job.update!(status: "failed", error: "#{e.class}: #{e.message}", finished_at: Time.current) rescue nil
    raise
  end
end