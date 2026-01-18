# frozen_string_literal: true

class UpdateScanRunsRemoveUniqueIndexAndAddFileIds < ActiveRecord::Migration[8.0]
  def change
    # 1) 删除 (repository_snapshot_id, lexical_pattern_id) 的唯一索引
    remove_index :scan_runs,
      name: "index_scan_runs_snapshot_pattern_unique",
      if_exists: true

    # 2) 增加 file_ids 字段（逗号分隔的大量 file id）
    add_column :scan_runs,
      :file_ids,
      :text
  end
end
