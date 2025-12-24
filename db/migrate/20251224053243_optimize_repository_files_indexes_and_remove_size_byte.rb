class OptimizeRepositoryFilesIndexesAndRemoveSizeByte < ActiveRecord::Migration[8.0]
  def change
    # 1) 删除 size_bytes 字段
    remove_column :repository_files, :size_bytes, :integer, if_exists: true

    # 2) 删除旧的唯一索引 (repository_id, blob_sha)
    remove_index :repository_files,
                 name: "index_repository_files_repo_blob_unique",
                 if_exists: true

    # 3) 新增更贴合查询的复合索引：
    #    repo.repository_files.find_or_initialize_by(blob_sha: ..., path: ...)
    #    => WHERE repository_id=? AND blob_sha=? AND path=?
    #
    # 建议 unique：避免并发导入时产生重复行（同 repo + 同 path + 同 blob）
    add_index :repository_files,
              [:repository_id, :blob_sha, :path],
              unique: true,
              name: "index_repository_files_on_repo_blob_path_unique",
              if_not_exists: true
  end
end
