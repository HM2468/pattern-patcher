# frozen_string_literal: true

class CreateLexemeProcessors < ActiveRecord::Migration[8.0]
  def change
    create_table :lexeme_processors do |t|
      t.string  :name, null: false
      t.string  :key, null: false
      t.string  :entrypoint, null: false
      t.jsonb   :default_config, null: false, default: {}
      t.jsonb   :output_schema,  null: false, default: {}
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :lexeme_processors, :key, unique: true
    add_index :lexeme_processors, :enabled
  end
end
