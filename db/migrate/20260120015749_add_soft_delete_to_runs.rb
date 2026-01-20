# frozen_string_literal: true

class AddSoftDeleteToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :scan_runs, :deleted_at, :datetime
    add_index  :scan_runs, :deleted_at

    add_column :process_runs, :deleted_at, :datetime
    add_index  :process_runs, :deleted_at
  end
end
