class CreateReplacementTargets < ActiveRecord::Migration[8.0]
  def change
    create_table :replacement_targets do |t|
      t.references :lexeme, null: false, foreign_key: true
      t.references :repository_file, null: false, foreign_key: true
      t.string :target_type
      t.string :target_value
      t.string :key_prefix
      t.text :rendered_code
      t.text :notes

      t.timestamps
    end
  end
end
