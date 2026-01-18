# frozen_string_literal: true

class CreateRepositorySnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :repository_snapshots do |t|
      t.references :repository, null: false, foreign_key: true
      t.string :commit_sha, null: false
      t.json :metadata

      t.timestamps
    end

    add_index :repository_snapshots, :commit_sha
    add_index :repository_snapshots, %i[repository_id commit_sha], unique: true
  end
end
