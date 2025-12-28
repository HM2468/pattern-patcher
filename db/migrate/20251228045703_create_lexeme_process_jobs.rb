# frozen_string_literal: true

class CreateLexemeProcessJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :lexeme_process_jobs do |t|
      t.references :lexeme_process, null: false, foreign_key: true

      t.string  :status, null: false, default: "pending"
      t.jsonb   :progress_persisted, null: false, default: {}

      t.text    :error
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :lexeme_process_jobs, :status
    add_index :lexeme_process_jobs, [:lexeme_process_id, :created_at]
  end
end