# frozen_string_literal: true

class CreateScanRunFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :scan_run_files do |t|
      t.references :scan_run, null: false, foreign_key: true
      t.references :repository_file, null: false, foreign_key: true

      t.string :status, null: false, default: "pending"
      t.text :error

      t.timestamps
    end

    add_index :scan_run_files,
      %i[scan_run_id repository_file_id],
      unique: true,
      name: "index_scan_run_files_on_scan_run_and_repo_file_unique"

    add_index :scan_run_files,
      %i[scan_run_id status],
      name: "index_scan_run_files_on_scan_run_id_and_status"
  end
end
