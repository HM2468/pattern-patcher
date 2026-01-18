# frozen_string_literal: true

class AddProgressPersistedToScanRuns < ActiveRecord::Migration[7.1]
  def change
    add_column :scan_runs, :progress_persisted, :jsonb, null: false, default: {}
  end
end
