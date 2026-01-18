# frozen_string_literal: true

class CreateOccurrences < ActiveRecord::Migration[8.0]
  def change
    create_table :occurrences do |t|
      t.references :scan_run, null: false, foreign_key: true
      t.references :lexeme, null: false, foreign_key: true
      t.references :lexical_pattern, null: false, foreign_key: true
      t.references :repository_file, null: false, foreign_key: true
      t.integer :line_at
      t.integer :idx_start
      t.integer :idx_end
      t.text :matched_text
      t.text :context_before
      t.text :context_after
      t.string :status

      t.timestamps
    end
  end
end
