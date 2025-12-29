# frozen_string_literal: true
# app/services/lexeme_processors/base_processor.rb
module LexemeProcessors
  class BaseProcessor
    attr_reader :config, :processor, :process_job

    # config: job_config merged with default_config (可在 job 层做 merge 提供过来)
    def initialize(config: {}, processor: nil, process_job: nil)
      @config = (config || {}).deep_dup
      @processor = processor
      @process_job = process_job
      raise ArgumentError, "process_job is required" unless @process_job&.id
    end

    # 子类必须实现：
    # @param lex_arr [Array<Hash>]
    # @return [Array<Hash>] results
    #
    # 输入 lex_arr 每项格式（统一）：
    #  { id: 123, normalized_text: "...", metadata: {...} }
    #
    # 输出 results 每项格式（统一）：
    #  { id: 123, output_json: {...}, metadata: {...} }
    #
    def run_process(lex_arr: [])
      raise NotImplementedError, "#{self.class} must implement #run_process"
    end

    # Lexeme -> input hash
    def build_input(lexemes)
      lexemes.map do |lx|
        {
          id: lx.id,
          normalized_text: lx.normalized_text.to_s,
          metadata: lx.metadata || {}
        }
      end
    end

    # 批量写入产物 + 更新 lexeme 状态 + 更新进度
    # @param results [Array<Hash>]
    #   { id: Integer, output_json: Hash, metadata: Hash }
    # @return [Integer] 本次成功处理（标记 processed）的 lexeme 数
    def write_results!(results: [])
      return 0 if results.blank?

      now = Time.current
      lexeme_ids = []
      rows = results.map do |res|
        lexeme_id = res.fetch(:id)
        lexeme_ids << lexeme_id
        {
          lexeme_process_job_id: process_job.id,
          lexeme_id: lexeme_id,
          metadata: (res[:metadata] || {}),
          output_json: (res[:output_json] || {}),
          created_at: now,
          updated_at: now
        }
      end

      batch_total = lexeme_ids.size
      # 事务保证：结果写入 与 lexeme 状态更新保持一致
      ActiveRecord::Base.transaction do
        # 幂等写入：避免并发/重试 insert_all 的唯一键冲突
        ::LexemeProcessResult.upsert_all(
          rows,
          unique_by: :idx_lexeme_process_results_unique
          # 如需严格控制更新列，可加：
          # update_only: %i[metadata output_json updated_at]
        )
        ::Lexeme.where(id: lexeme_ids).update_all(
          process_status: "processed",
          updated_at: now
        )
      end
      # 进度计数：Redis 原子累加
      Rails.cache.increment(process_job.succeed_count_key, batch_total)
      batch_total
    rescue => e
      # DB 写失败 / 事务失败：把 lexeme 标记为 failed（尽力而为）
      begin
        ::Lexeme.where(id: lexeme_ids).update_all(
          process_status: "failed",
          updated_at: Time.current
        )
      rescue => e2
        Rails.logger&.error("[BaseProcessor] failed to mark lexemes failed: #{e2.class}: #{e2.message}")
      end
      # 失败计数：用 batch_total（本批数量）
      begin
        Rails.cache.increment(process_job.failed_count_key, batch_total)
      rescue => e3
        Rails.logger&.error("[BaseProcessor] failed to increment failed counter: #{e3.class}: #{e3.message}")
      end
      Rails.logger&.error(
        "[BaseProcessor] write_results! failed job_id=#{process_job.id} lexeme_ids=#{lexeme_ids.take(20)}" \
        " err=#{e.class}: #{e.message}"
      )
      0
    end
  end
end