class CreateScanRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :scan_runs do |t|
      t.references :repository_file, null: false, foreign_key: true
      t.references :lexical_pattern, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :finished_at
      t.string :patterns_snapshot
      t.string :text
      t.text :error
      t.text :notes

      t.timestamps
    end
  end
end
