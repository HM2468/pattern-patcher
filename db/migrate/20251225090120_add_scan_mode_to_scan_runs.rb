# frozen_string_literal: true

class AddScanModeToScanRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :scan_runs, :scan_mode, :string, null: false, default: "line"
    add_index  :scan_runs, :scan_mode

    # Optional: if you already have rows and want them normalized
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE scan_runs
          SET scan_mode = 'line'
          WHERE scan_mode IS NULL OR scan_mode = ''
        SQL
      end
    end
  end
end
