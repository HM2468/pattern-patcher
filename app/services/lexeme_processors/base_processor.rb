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

    # 将 occurrence 中的 matched_text 替换为 rendered_code
    #
    # @param config [Hash]
    # @param lexeme_metadata [Hash]
    # @param lps_output [Hash]
    # @param file_path [String]
    # @return [Array(String, Hash)] rendered_code, metadata
    def generate_rendered_code(
      config: {},
      lexeme_metadata: {},
      lps_output: {},
      file_path: ""
    )
      raise NotImplementedError, "#{self.class} must implement #generate_rendered_code"
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
    # 关键改进点：
    # - 预加载 Lexeme / Occurrence / RepositoryFile，避免 N+1
    # - transaction 缩小到：LexemeProcessResult + Lexeme 状态（必要的一致性）
    # - Occurrence status 用 update_all 批量落库（减少 SQL）
    #
    # @param results [Array<Hash>]
    def write_results!(results: [])
      return if results.blank?

      # ---- 1) normalize ids + preload records (avoid N+1) ----
      lexeme_ids = results.map { |r| (r[:id] || r["id"]).to_i }.uniq
      lexemes_by_id = ::Lexeme.where(id: lexeme_ids).index_by(&:id)

      # 只处理当前仍是 unprocessed 的 occurrences，并预加载 repository_file 避免 occ.repository_file N+1
      occs_by_lexeme_id =
        ::Occurrence
          .where(lexeme_id: lexeme_ids)
          .unprocessed
          .includes(:repository_file)
          .group_by(&:lexeme_id)

      results.each do |res|
        lexeme_id = (res[:id] || res["id"]).to_i
        lexeme = lexemes_by_id[lexeme_id]

        if lexeme.nil?
          Rails.cache.increment(run.failed_count_key, 1)
          Rails.logger&.warn("[BaseProcessor] lexeme not found run_id=#{run.id} lexeme_id=#{lexeme_id}")
          next
        end

        # 当前 lexeme 对应的未处理 occurrences（可能为空）
        occs = occs_by_lexeme_id[lexeme_id] || []

        # 统一提取 res_attrs，避免 block 作用域/异常导致外部用到 nil
        res_attrs = {
          metadata: (res[:metadata] || res["metadata"] || {}),
          output_json: (res[:output_json] || res["output_json"] || {})
        }

        begin
          # ---- 2) minimal transaction: result row + lexeme status ----
          ::LexemeProcessResult.transaction do
            res_ar = ::LexemeProcessResult.find_or_initialize_by(
              process_run_id: run.id,
              lexeme_id: lexeme.id
            )
            res_ar.assign_attributes(res_attrs)
            res_ar.save!
            lexeme.update!(process_status: "processed")
          end

          # ---- 3) occurrences: build review results (no big transaction) ----
          processed_occ_ids = []

          occs.each do |occ|
            # repository_file 已 includes 预加载
            rendered_code, metadata = generate_rendered_code(
              config: config,
              lexeme_metadata: lexeme.metadata || {},
              lps_output: res_attrs[:output_json] || {},
              file_path: occ.repository_file&.path.to_s
            )

            occ_rev_attrs = {
              status: "pending",
              apply_status: "not_applied",
              metadata: metadata,
              rendered_code: rendered_code
            }

            occ_rev_ar = ::OccurrenceReview.find_or_initialize_by(occurrence_id: occ.id)
            occ_rev_ar.assign_attributes(occ_rev_attrs)
            occ_rev_ar.save!
            Rails.cache.increment(run.occ_rev_count_key, 1)
            processed_occ_ids << occ.id
          end

          # ---- 4) bulk update occurrence status ----
          if processed_occ_ids.any?
            ::Occurrence.where(id: processed_occ_ids).update_all(status: "processed", updated_at: Time.current)
          end

          Rails.cache.increment(run.succeed_count_key, 1)
        rescue => e
          Rails.cache.increment(run.failed_count_key, 1)

          # best-effort：标记失败，但不要再抛异常影响后续处理
          begin
            lexeme.update(process_status: "failed")
          rescue => _e2
            # ignore
          end

          Rails.logger&.error(
            "[BaseProcessor] save_result failed run_id=#{run.id} lexeme_id=#{lexeme.id} err=#{e.class}: #{e.message}"
          )
          next
        end
      end
    end
  end
end