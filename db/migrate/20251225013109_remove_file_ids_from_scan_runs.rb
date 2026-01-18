# frozen_string_literal: true

class RemoveFileIdsFromScanRuns < ActiveRecord::Migration[8.0]
  def change
    remove_column :scan_runs, :file_ids, :text
  end
end
