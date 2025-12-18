class CreateReplacementActions < ActiveRecord::Migration[8.0]
  def change
    create_table :replacement_actions do |t|
      t.references :occurrence, null: false, foreign_key: true
      t.references :repository_file, null: false, foreign_key: true
      t.text :original_fragment
      t.text :patched_fragment
      t.text :original_line
      t.text :patched_line
      t.string :base_file_sha
      t.string :decision
      t.string :status
      t.datetime :applied_at
      t.datetime :rejected_at
      t.text :rejected_reason
      t.text :error

      t.timestamps
    end
  end
end
