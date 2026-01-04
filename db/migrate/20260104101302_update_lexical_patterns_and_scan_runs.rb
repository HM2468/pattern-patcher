class UpdateLexicalPatternsAndScanRuns < ActiveRecord::Migration[8.0]
  def change
    remove_column :lexical_patterns, :pattern_type, :string
    remove_column :lexical_patterns, :priority, :integer

    rename_column :lexical_patterns, :mode, :scan_mode
    change_column_default :lexical_patterns, :scan_mode, from: "line", to: "line_mode"

    remove_column :scan_runs, :scan_mode, :string

    remove_column :scan_runs, :pattern_snapshot, :text
    add_column :scan_runs, :pattern_snapshot, :jsonb, default: {}, null: false
  end
end