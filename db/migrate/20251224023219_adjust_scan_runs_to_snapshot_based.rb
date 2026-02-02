# frozen_string_literal: true

class AdjustScanRunsToSnapshotBased < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:scan_runs, :repository_snapshot_id)
      add_reference :scan_runs, :repository_snapshot, null: true, foreign_key: true
    end

    if column_exists?(:scan_runs, :patterns_snapshot) && !column_exists?(:scan_runs, :pattern_snapshot)
      rename_column :scan_runs, :patterns_snapshot, :pattern_snapshot
    end

    change_column :scan_runs, :pattern_snapshot, :text if column_exists?(:scan_runs, :pattern_snapshot)
    add_column :scan_runs, :cursor, :json unless column_exists?(:scan_runs, :cursor)

    remove_column :scan_runs, :text if column_exists?(:scan_runs, :text)

    if index_name_exists?(:scan_runs,
      "index_scan_runs_on_repository_file_id_and_lexical_pattern_id")
      remove_index :scan_runs,
        name: "index_scan_runs_on_repository_file_id_and_lexical_pattern_id"
    end
    if index_name_exists?(:scan_runs,
      "index_scan_runs_on_repository_file_id")
      remove_index :scan_runs,
        name: "index_scan_runs_on_repository_file_id"
    end

    unless index_exists?(:scan_runs,
      %i[repository_snapshot_id lexical_pattern_id], unique: true, name: "index_scan_runs_snapshot_pattern_unique")
      add_index :scan_runs, %i[repository_snapshot_id lexical_pattern_id],
        unique: true,
        name: "index_scan_runs_snapshot_pattern_unique"
    end

    add_index :scan_runs, :status unless index_exists?(:scan_runs, :status)
    remove_foreign_key :scan_runs, :repository_files if foreign_key_exists?(:scan_runs, :repository_files)
    remove_column :scan_runs, :repository_file_id if column_exists?(:scan_runs, :repository_file_id)
    change_column_null :scan_runs, :repository_snapshot_id, false
  end
end
