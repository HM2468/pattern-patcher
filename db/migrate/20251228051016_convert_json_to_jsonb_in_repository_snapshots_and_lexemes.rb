# frozen_string_literal: true

class ConvertJsonToJsonbInRepositorySnapshotsAndLexemes < ActiveRecord::Migration[8.0]
  def up
    # repository_snapshots.metadata
    change_column :repository_snapshots,
      :metadata,
      :jsonb,
      using: "metadata::jsonb"

    # lexemes.metadata
    change_column :lexemes,
      :metadata,
      :jsonb,
      using: "metadata::jsonb"
  end

  def down
    change_column :repository_snapshots,
      :metadata,
      :json,
      using: "metadata::json"

    change_column :lexemes,
      :metadata,
      :json,
      using: "metadata::json"
  end
end
