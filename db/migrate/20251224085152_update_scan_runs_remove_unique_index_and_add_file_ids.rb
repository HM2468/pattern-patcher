# frozen_string_literal: true

class UpdateScanRunsRemoveUniqueIndexAndAddFileIds < ActiveRecord::Migration[8.0]
  def change
    remove_index :scan_runs,
      name: "index_scan_runs_snapshot_pattern_unique",
      if_exists: true

    add_column :scan_runs,
      :file_ids,
      :text
  end
end
