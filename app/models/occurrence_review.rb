# frozen_string_literal: true

# app/models/occurrence_review.rb
class OccurrenceReview < ApplicationRecord
  belongs_to :occurrence
  validates :status, presence: true
  validates :apply_status, presence: true

  enum status: {
    pending: "pending",
    reviewed: "reviewed",
    approved: "approved",
    rejected: "rejected"
  }, default: :pending

  enum apply_status: {
    not_applied: "not_applied",
    applied: "applied",
    failed: "failed",
    conflict: "conflict"
  }, default: :not_applied

  # Default values are handled by the database schema, so we don't need to set them here
  # metadata: {}, status: "pending"
end