class ModifyRepositoriesStructure < ActiveRecord::Migration[8.0]
  def change
    # 删除索引
    remove_index :repositories, name: :index_repositories_on_repo_uid
    # 删除列
    remove_column :repositories, :repo_uid
    # 新增列
    add_column :repositories, :permitted_ext, :string
  end
end
