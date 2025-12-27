# frozen_string_literal: true
class AddMatchFingerprintToOccurrences < ActiveRecord::Migration[7.1]
  def change
    add_column :occurrences, :match_fingerprint, :string, null: false
    add_index :occurrences, :match_fingerprint, unique: true
  end
end