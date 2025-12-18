class CreateLexicalPatterns < ActiveRecord::Migration[8.0]
  def change
    create_table :lexical_patterns do |t|
      t.string :name
      t.text :pattern
      t.string :language
      t.string :pattern_type
      t.integer :priority
      t.boolean :enabled

      t.timestamps
    end
  end
end
