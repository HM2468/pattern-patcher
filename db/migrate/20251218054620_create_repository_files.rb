# frozen_string_literal: true

class CreateRepositoryFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :repository_files do |t|
      t.references :repository, null: false, foreign_key: true
      t.string :path
      t.string :file_sha
      t.integer :size_bytes
      t.datetime :last_scanned_at

      t.timestamps
    end
  end
end
