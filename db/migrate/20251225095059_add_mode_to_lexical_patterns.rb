# frozen_string_literal: true

class AddModeToLexicalPatterns < ActiveRecord::Migration[8.0]
  def change
    add_column :lexical_patterns, :mode, :string, null: false, default: "line"
    add_index  :lexical_patterns, :mode
  end
end