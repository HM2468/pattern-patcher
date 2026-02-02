# frozen_string_literal: true

class AdjustRepositoryFilesForGitBlobs < ActiveRecord::Migration[8.0]
  def change

    if column_exists?(:repository_files, :file_sha) && !column_exists?(:repository_files, :blob_sha)
      rename_column :repository_files, :file_sha, :blob_sha
    end

    remove_index :repository_files, name: "index_repository_files_on_file_sha" if index_name_exists?(:repository_files,
      "index_repository_files_on_file_sha")
    remove_index :repository_files, name: "index_repository_files_on_repository_id_and_path" if index_name_exists?(
      :repository_files, "index_repository_files_on_repository_id_and_path"
    )

    unless index_exists?(
      :repository_files, %i[repository_id blob_sha], unique: true, name: "index_repository_files_repo_blob_unique"
    )
      add_index :repository_files, %i[repository_id blob_sha], unique: true,
        name: "index_repository_files_repo_blob_unique"
    end
    add_index :repository_files, :blob_sha, name: "index_repository_files_on_blob_sha" unless index_exists?(
      :repository_files, :blob_sha, name: "index_repository_files_on_blob_sha"
    )
    add_index :repository_files, :path, name: "index_repository_files_on_path" unless index_exists?(:repository_files,
      :path, name: "index_repository_files_on_path")
  end
end
