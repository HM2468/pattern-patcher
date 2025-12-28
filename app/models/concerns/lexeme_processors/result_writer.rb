# app/models/concerns/lexeme_processors/result_writer.rb
module LexemeProcessors
  module ResultWriter
    extend ActiveSupport::Concern

    # outputs: { lexeme_id => { output_json: {...}, metadata: {...} } }
    def write_results!(lexeme_process_job:, outputs:)
      now = Time.current
      rows = outputs.map do |lexeme_id, out|
        {
          lexeme_process_job_id: lexeme_process_job.id,
          lexeme_id: lexeme_id,
          output_json: out.fetch(:output_json, {}),
          metadata: out.fetch(:metadata, {}),
          created_at: now,
          updated_at: now
        }
      end

      ::LexemeProcessResult.upsert_all(
        rows,
        unique_by: :idx_lexeme_process_results_unique
      )
    end

    def write_result!(lexeme_process_job:, lexeme:, output:)
      ::LexemeProcessResult.upsert(
        {
          lexeme_process_job_id: lexeme_process_job.id,
          lexeme_id: lexeme.id,
          output_json: output.fetch(:output_json, {}),
          metadata: output.fetch(:metadata, {}),
          created_at: Time.current,
          updated_at: Time.current
        },
        unique_by: :idx_lexeme_process_results_unique
      )
    end
  end
end