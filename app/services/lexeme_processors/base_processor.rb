# frozen_string_literal: true

# app/services/lexeme_processors/base_processor.rb
module LexemeProcessors
  class BaseProcessor
    attr_reader :config, :processor, :run

    # config: job_config merged with default_config (可在 job 层做 merge 提供过来)
    def initialize(config: {}, processor: nil, run: nil)
      @config = (config || {}).deep_dup
      @processor = processor
      @run = run
      raise ArgumentError, "run is required" unless @run&.id
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

    # 逐条写入产物 + 逐条更新 lexeme 状态 + 逐条更新进度
    #
    # 设计目标：
    # - 本地单机工具：用“逐条”换更细粒度的进度 & 更易定位失败记录
    # - 单条失败不影响其它记录（best-effort）
    #
    # @param results [Array<Hash>]
    def write_results!(results: [])
      return if results.blank?

      results.each do |res|
        lexeme_id = (res[:id] || res['id']).to_i
        lexeme = ::Lexeme.find_by(id: lexeme_id)
        if lexeme.nil?
          Rails.cache.increment(run.failed_count_key, 1)
          Rails.logger&.warn("[BaseProcessor] lexeme not found run_id=#{run.id} lexeme_id=#{lexeme_id}")
          next
        end

        attrs = {
          metadata: (res[:metadata] || res["metadata"] || {}),
          output_json: (res[:output_json] || res["output_json"] || {})
        }

        begin
          ::LexemeProcessResult.transaction do
            result_ar = ::LexemeProcessResult.find_or_initialize_by(process_run_id: run.id, lexeme_id: lexeme.id)
            result_ar.assign_attributes(attrs)
            result_ar.save!
            lexeme.update!(process_status: "processed")
          end
          Rails.cache.increment(run.succeed_count_key, 1)
        rescue => e
          Rails.cache.increment(run.failed_count_key, 1)
          lexeme.update(process_status: "failed")
          Rails.logger&.error("[BaseProcessor] save_result failed run_id=#{run.id} lexeme_id=#{lexeme.id} err=#{e.class}: #{e.message}")
          next
        end
      end
    end
  end
end