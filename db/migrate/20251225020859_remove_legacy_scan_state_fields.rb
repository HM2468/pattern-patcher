# frozen_string_literal: true

class RemoveLegacyScanStateFields < ActiveRecord::Migration[8.0]
  def change
    # repository_files.last_scanned_at
    if column_exists?(:repository_files, :last_scanned_at)
      remove_column :repository_files, :last_scanned_at, :datetime
    end

    # scan_runs.cursor
    if column_exists?(:scan_runs, :cursor)
      remove_column :scan_runs, :cursor, :json
    end
  end
end