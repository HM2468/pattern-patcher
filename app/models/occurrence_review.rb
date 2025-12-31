# frozen_string_literal: true

# app/models/occurrence_review.rb
class OccurrenceReview < ApplicationRecord
  belongs_to :occurrence
  validates :status, presence: true

  enum status: {
    pending: "pending",
    reviewed: "reviewed",
    approved: "approved",
    rejected: "rejected"
  }

  enum apply_status: {
    not_applied: nil,
    applied: "applied",
    failed: "failed",
    conflict: "conflict"
  }

  # Default values are handled by the database schema, so we don't need to set them here
  # metadata: {}, status: "pending"
end