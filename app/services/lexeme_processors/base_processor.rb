# frozen_string_literal: true

# app/services/lexeme_processors/base_processor.rb
module LexemeProcessors
  class BaseProcessor
    attr_reader :config, :processor, :run

    # config: job_config merged with default_config
    def initialize(config: {}, processor: nil, run: nil)
      @config = (config || {}).deep_dup
      @processor = processor
      @run = run
      raise ArgumentError, "run is required" unless @run&.id
    end

    # Subclasses must implement:
    # @param lex_arr [Array<Hash>]
    # @return [Array<Hash>] results
    #
    # Input lex_arr item format (standardized):
    #  { id: 123, normalized_text: "...", metadata: {...} }
    #
    # Output results item format (standardized):
    #  { id: 123, output_json: {...}, metadata: {...} }
    #
    def run_process(lex_arr: [])
      raise NotImplementedError, "#{self.class} must implement #run_process"
    end

    # Replace occurrence.matched_text with rendered_code
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

    # Persist outputs one-by-one + update lexeme status one-by-one + update progress one-by-one
    # @param results [Array<Hash>]
    def write_results!(results: [])
      return if results.blank?

      # 1) normalize ids + preload records (avoid N+1)
      lexeme_ids = results.map { |r| (r[:id] || r["id"]).to_i }.uniq
      lexemes_by_id = ::Lexeme.where(id: lexeme_ids).index_by(&:id)

      # Only process occurrences that are still unprocessed, and preload repository_file
      # to avoid occ.repository_file N+1 queries
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

        # Unprocessed occurrences for current lexeme (may be empty)
        occs = occs_by_lexeme_id[lexeme_id] || []

        # Normalize extracted res_attrs to avoid nil usage caused by block scope/exceptions
        res_attrs = {
          metadata: (res[:metadata] || res["metadata"] || {}),
          output_json: (res[:output_json] || res["output_json"] || {})
        }

        begin
          # 2) minimal transaction: result row + lexeme status
          ::LexemeProcessResult.transaction do
            res_ar = ::LexemeProcessResult.find_or_initialize_by(
              process_run_id: run.id,
              lexeme_id: lexeme.id
            )
            res_ar.assign_attributes(res_attrs)
            res_ar.save!
            lexeme.update!(process_status: "processed")
          end

          # 3) occurrences: build review results (no big transaction)
          processed_occ_ids = []

          occs.each do |occ|
            # repository_file is preloaded via includes
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

          # 4) bulk update occurrence status
          if processed_occ_ids.any?
            ::Occurrence.where(id: processed_occ_ids).update_all(status: "processed", updated_at: Time.current)
          end

          Rails.cache.increment(run.succeed_count_key, 1)
        rescue => e
          Rails.cache.increment(run.failed_count_key, 1)

          # Best-effort: mark lexeme as failed, but do not re-raise and block subsequent processing
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