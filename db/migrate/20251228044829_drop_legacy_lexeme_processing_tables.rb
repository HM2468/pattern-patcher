# frozen_string_literal: true

class DropLegacyLexemeProcessingTables < ActiveRecord::Migration[8.0]
  def up
    if table_exists?(:replacement_actions)
      drop_table :replacement_actions
    end

    if table_exists?(:replacement_targets)
      drop_table :replacement_targets
    end

    if table_exists?(:lexeme_processings)
      drop_table :lexeme_processings
    end
  end
end