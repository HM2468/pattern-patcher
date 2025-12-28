# frozen_string_literal: true

class CreateOccurrenceReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :occurrence_reviews do |t|
      t.references :occurrence, null: false, foreign_key: true

      t.jsonb  :metadata, null: false, default: {}
      t.text   :rendered_code

      t.string :status, null: false, default: "pending"
      t.string :apply_status

      t.timestamps
    end

    add_index :occurrence_reviews, :status
    add_index :occurrence_reviews, :apply_status
  end
end