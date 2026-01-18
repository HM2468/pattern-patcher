# frozen_string_literal: true

class CreateRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :repositories do |t|
      t.string :name
      t.string :root_path
      t.string :repo_uid
      t.string :status

      t.timestamps
    end
  end
end
