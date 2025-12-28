# frozen_string_literal: true
# app/services/lexeme_processors/base_processor.rb
module LexemeProcessors
  class BaseProcessor
    attr_reader :config, :processor, :process_job

    DEFAULT_MAX_TOKENS_PER_BATCH = 1_500

    # config: job_config merged with default_config (可在 job 层做 merge 提供过来)
    def initialize(config: {}, processor: nil, process_job: nil)
      @config = (config || {}).deep_dup
      @processor = processor
      @process_job = process_job
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

    # === Public: helpers ===

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

    # 批量写入产物
    # @param results [Array<Hash>] reminder:
    #   { id: Integer, output_json: Hash, metadata: Hash }
    def write_results!(results: [])
      return 0 if results.blank?
      raise ArgumentError, "process_job is required" unless process_job&.id

      now = Time.current
      rows = results.map do |res|
        lexeme_id = res.fetch(:id)
        {
          lexeme_process_job_id: process_job.id,
          lexeme_id: lexeme_id,
          metadata: (res[:metadata] || {}),
          output_json: (res[:output_json] || {}),
          created_at: now,
          updated_at: now
        }
      end

      # upsert_all 返回值各版本 Rails 有差异，这里返回写入行数更直观
      ::LexemeProcessResult.upsert_all(
        rows,
        unique_by: :idx_lexeme_process_results_unique
      )

      rows.size
    end

    # 根据 token 估算把 lexemes 分批
    def batch_by_token(lexemes, max_tokens: DEFAULT_MAX_TOKENS_PER_BATCH)
      items = lexemes.map { |lx| [lx, estimate_tokens(lx.normalized_text)] }
                     .sort_by { |(_lx, t)| -t } # long first

      batches = []
      current = []
      current_tokens = 0

      items.each do |lx, t|
        # 单条超大：单独一批（否则永远装不进去）
        if t >= max_tokens
          batches << [lx]
          next
        end

        if current_tokens + t > max_tokens
          batches << current if current.any?
          current = [lx]
          current_tokens = t
          next
        end

        current << lx
        current_tokens += t
      end

      batches << current if current.any?
      batches
    end

    # 粗略 token 估算：UTF-8 bytes / 4
    def estimate_tokens(text)
      s = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")
      (s.bytesize / 4.0).ceil
    end
  end
end