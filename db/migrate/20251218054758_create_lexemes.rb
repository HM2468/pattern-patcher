# frozen_string_literal: true

class CreateLexemes < ActiveRecord::Migration[8.0]
  def change
    create_table :lexemes do |t|
      t.text :source_text
      t.text :normalized_text
      t.string :fingerprint
      t.string :locale
      t.json :metadata
      t.datetime :processed_at

      t.timestamps
    end
  end
end
