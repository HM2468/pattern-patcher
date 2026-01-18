# frozen_string_literal: true

class AdjustRepositoriesForSnapshots < ActiveRecord::Migration[8.0]
  def change
    return unless column_exists?(:repositories, :status)

    remove_index :repositories, name: "index_repositories_on_status" if index_name_exists?(:repositories,
      "index_repositories_on_status")
    remove_column :repositories, :status
  end
end
