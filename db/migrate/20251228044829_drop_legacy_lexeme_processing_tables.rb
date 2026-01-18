# frozen_string_literal: true

class DropLegacyLexemeProcessingTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :replacement_actions if table_exists?(:replacement_actions)

    drop_table :replacement_targets if table_exists?(:replacement_targets)

    return unless table_exists?(:lexeme_processings)

    drop_table :lexeme_processings
  end
end
