# frozen_string_literal: true

class CreateLexemeProcessResults < ActiveRecord::Migration[8.0]
  def change
    create_table :lexeme_process_results do |t|
      t.references :lexeme_process_job, null: false, foreign_key: true
      t.references :lexeme, null: false, foreign_key: true

      t.jsonb :metadata, null: false, default: {}
      t.jsonb :output_json, null: false, default: {}

      t.timestamps
    end

    add_index :lexeme_process_results,
      %i[lexeme_process_job_id lexeme_id],
      unique: true,
      name: "idx_lexeme_process_results_unique"
  end
end
