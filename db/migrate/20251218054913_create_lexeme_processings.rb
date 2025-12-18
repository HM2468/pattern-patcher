class CreateLexemeProcessings < ActiveRecord::Migration[8.0]
  def change
    create_table :lexeme_processings do |t|
      t.references :lexeme, null: false, foreign_key: true
      t.string :process_type
      t.string :locale
      t.text :output
      t.string :provider
      t.string :model
      t.string :status
      t.text :error
      t.json :metadata

      t.timestamps
    end
  end
end
