# frozen_string_literal: true

# app/models/occurrence_review.rb
class OccurrenceReview < ApplicationRecord
  belongs_to :occurrence
  validates :status, presence: true
  validates :apply_status, presence: true

  enum :status, {
    pending: "pending",
    approved: "approved",
    rejected: "rejected"
  }, default: :pending

  enum :apply_status, {
    not_applied: "not_applied",
    applied: "applied",
    failed: "failed",
    conflict: "conflict"
  }, default: :not_applied

  # Apply patch into working tree:
  # Replace occurrence.matched_text at [s...e] on line_at with rendered_code
  #
  # Returns true if applied, false otherwise
  def apply_patch!
    occ = occurrence
    rf  = occ&.repository_file

    unless occ && rf
      errors.add(:base, "Missing occurrence or repository file")
      update!(apply_status: :failed)
      return false
    end

    rendered = rendered_code.to_s
    if rendered.blank?
      errors.add(:rendered_code, "cannot be blank")
      update!(apply_status: :failed)
      return false
    end

    line_at = occ.line_at.to_i
    s = occ.line_char_start&.to_i
    e = occ.line_char_end&.to_i # EXCLUSIVE

    if line_at <= 0 || s.nil? || e.nil? || s.negative? || e < s
      errors.add(
        :base,
        "Invalid position info (line_at=#{occ.line_at}, start=#{s}, end=#{e})"
      )
      update!(apply_status: :failed)
      return false
    end

    abs = rf.absolute_path.to_s
    content = rf.raw_content.to_s

    if content.blank?
      errors.add(:base, "File content is empty or unreadable")
      update!(apply_status: :failed)
      return false
    end

    lines = content.lines
    idx = line_at - 1

    if idx.negative? || idx >= lines.length
      errors.add(
        :base,
        "line_at #{line_at} is out of file range (total lines: #{lines.length})"
      )
      update!(apply_status: :failed)
      return false
    end

    line = lines[idx].to_s

    if s > line.length
      return conflict!(
        "Start index #{s} exceeds line length #{line.length}",
        occ,
        rf,
        line_at,
        s,
        e,
        line
      )
    end

    e = [e, line.length].min
    current_segment = line[s...e].to_s
    expected_old    = occ.matched_text.to_s

    if current_segment != expected_old
      errors.add(
        :base,
        "Conflict detected: file content has changed since scan"
      )
      update!(apply_status: :conflict)
      return false
    end

    line[s...e] = rendered
    lines[idx] = line
    new_content = lines.join

    begin
      tmp = "#{abs}.tmp.#{Process.pid}.#{SecureRandom.hex(6)}"
      File.open(tmp, "wb") { |f| f.write(new_content) }
      File.rename(tmp, abs)

      update!(apply_status: :applied)
      true
    rescue StandardError => ex
      errors.add(
        :base,
        "Failed to write file: #{ex.message}"
      )
      update!(apply_status: :failed)
      false
    ensure
      begin
        File.delete(tmp) if defined?(tmp) && tmp.present? && File.exist?(tmp)
      rescue StandardError
        # ignore cleanup failure
      end
    end
  end

  private

  def conflict!(reason, occ, rf, line_at, s, e, line)
    errors.add(:base, "Conflict: #{reason}")
    update!(apply_status: :conflict)
    false
  end
end