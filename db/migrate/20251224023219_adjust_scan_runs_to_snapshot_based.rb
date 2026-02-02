# frozen_string_literal: true

class AdjustScanRunsToSnapshotBased < ActiveRecord::Migration[8.0]
  def change
    # 1) 新增 repository_snapshot_id
    unless column_exists?(:scan_runs, :repository_snapshot_id)
      add_reference :scan_runs, :repository_snapshot, null: true, foreign_key: true
    end

    # 2) 重命名 patterns_snapshot -> pattern_snapshot（并改为 text）
    if column_exists?(:scan_runs, :patterns_snapshot) && !column_exists?(:scan_runs, :pattern_snapshot)
      rename_column :scan_runs, :patterns_snapshot, :pattern_snapshot
    end

    # patterns_snapshot
    change_column :scan_runs, :pattern_snapshot, :text if column_exists?(:scan_runs, :pattern_snapshot)

    # 3) 新增 cursor(json)
    add_column :scan_runs, :cursor, :json unless column_exists?(:scan_runs, :cursor)

    # 4) 删除误入字段 text
    remove_column :scan_runs, :text if column_exists?(:scan_runs, :text)

    # 5) 移除旧索引（基于 repository_file_id）
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

    # 6) 新增新索引
    unless index_exists?(:scan_runs,
      %i[repository_snapshot_id lexical_pattern_id], unique: true, name: "index_scan_runs_snapshot_pattern_unique")
      add_index :scan_runs, %i[repository_snapshot_id lexical_pattern_id],
        unique: true,
        name: "index_scan_runs_snapshot_pattern_unique"
    end

    add_index :scan_runs, :status unless index_exists?(:scan_runs, :status)

    # 7) 移除旧外键和列 repository_file_id
    remove_foreign_key :scan_runs, :repository_files if foreign_key_exists?(:scan_runs, :repository_files)

    remove_column :scan_runs, :repository_file_id if column_exists?(:scan_runs, :repository_file_id)

    # 8) 最后把 repository_snapshot_id 设为 NOT NULL
    change_column_null :scan_runs, :repository_snapshot_id, false
  end
end
