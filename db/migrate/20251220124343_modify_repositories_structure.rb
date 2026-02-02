# frozen_string_literal: true

class ModifyRepositoriesStructure < ActiveRecord::Migration[8.0]
  def change
    remove_index :repositories, name: :index_repositories_on_repo_uid
    remove_column :repositories, :repo_uid
    add_column :repositories, :permitted_ext, :string
  end
end
