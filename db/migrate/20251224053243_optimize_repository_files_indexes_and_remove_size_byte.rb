# frozen_string_literal: true

class OptimizeRepositoryFilesIndexesAndRemoveSizeByte < ActiveRecord::Migration[8.0]
  def change
    remove_column :repository_files, :size_bytes, :integer, if_exists: true

    remove_index :repository_files,
      name: "index_repository_files_repo_blob_unique",
      if_exists: true

    add_index :repository_files,
      %i[repository_id blob_sha path],
      unique: true,
      name: "index_repository_files_on_repo_blob_path_unique",
      if_not_exists: true
  end
end
