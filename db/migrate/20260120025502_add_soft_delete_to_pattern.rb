# frozen_string_literal: true

class AddSoftDeleteToPattern < ActiveRecord::Migration[8.1]
  def change
    add_column :lexical_patterns, :deleted_at, :datetime
    add_index  :lexical_patterns, :deleted_at
  end
end
