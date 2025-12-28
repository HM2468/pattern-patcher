# app/jobs/lexeme_process_batch_job.rb
class LexemeProcessBatchJob < ApplicationJob
  queue_as :lexeme_process

  def perform(lexeme_process_job_id:, lexeme_ids:, config:)
    job = LexemeProcessJob.find(lexeme_process_job_id)
    processor = job.lexeme_processor

    lexemes = Lexeme.where(id: lexeme_ids)

    # 并发控制：把本批 pending 的 lexeme 原子改成 processing
    # 只处理本次成功“抢到”的那部分
    claimed_ids = Lexeme.where(id: lexeme_ids, process_status: "pending")
                        .update_all(process_status: "processing") # rubocop:disable Rails/SkipsModelValidations

    # 重新只取 processing 的
    lexemes = Lexeme.where(id: lexeme_ids, process_status: "processing")
    return if lexemes.blank? # 说明都被其他 job 抢走了

    processor.process_batch!(lexeme_process_job: job, lexemes: lexemes, config: config)

    # 成功标记
    Lexeme.where(id: lexemes.pluck(:id)).update_all( # rubocop:disable Rails/SkipsModelValidations
      process_status: "succeeded",
      processed_at: Time.current
    )

    job.increment_progress!(done: lexemes.size, failed: 0)
  rescue => e
    # 失败：把 batch 的 lexemes 标记 failed（但不要覆盖已成功的）
    Lexeme.where(id: lexeme_ids, process_status: "processing")
          .update_all(process_status: "failed", processed_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    job.increment_progress!(done: 0, failed: lexeme_ids.size, error: "#{e.class}: #{e.message}")
    raise
  ensure
    job.try_finalize!
  end
end