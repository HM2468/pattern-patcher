# frozen_string_literal: true
# app/services/approve_occurrence_review_service.rb
class ApproveOccurrenceReviewService
  Result = Struct.new(:ok?, :message, :errors, :committed, keyword_init: true)

  def initialize(occ_rev:)
    @review = occ_rev
    @occurrence = @review&.occurrence
    @file = @occurrence&.repository_file
    @repository = @file&.repository
    @git_cli = @repository&.git_cli
    @errors = []
    @committed = false

    validate_presence
  end

  def execute
    return fail_result if @errors.any?

    # 1) apply patch (write working tree file)
    return fail_result unless apply_patch!

    # 2) mark current review approved
    return fail_result unless update_review_status_approved!

    # 3) Every approve -> git add this file (stage the current file state)
    begin
      @git_cli.add_file(@file.path)
    rescue StandardError => e
      @errors << "git add failed: #{e.message}"
      return fail_result
    end

    # 4) If ALL reviews for this file are approved -> commit ONLY this file
    if all_reviews_for_file_approved?
      begin
        if @git_cli.has_changes_for_path?(@file.path)
          msg = build_commit_message
          @git_cli.commit_file(msg, @file.path, no_verify: true)
          @committed = true
        end
      rescue StandardError => e
        Rails.logger.error(
          "[ApproveOccurrenceReviewService] git commit (file-only) failed",
          occurrence_review_id: @review.id,
          file: @file.path,
          error: e.class.name,
          message: e.message,
          backtrace: e.backtrace&.first(10)
        )

        @errors << "git commit failed (details logged)."
        @errors << e.message.to_s.byteslice(0, 300)
        return fail_result
      end
    end

    # 5) reserved post_patch hook
    begin
      post_patch(@review)
    rescue StandardError => e
      @errors << "post_patch failed: #{e.message}"
      return fail_result
    end

    Result.new(ok?: true, message: success_message, errors: [], committed: @committed)
  end

  private

  # init validations
  def validate_presence
    unless @review.is_a?(OccurrenceReview)
      @errors << "Invalid input: occ_rev must be an OccurrenceReview"
      return
    end
    @errors << "Missing occurrence" if @occurrence.nil?
    @errors << "Missing repository file" if @file.nil?
    @errors << "Missing repository" if @repository.nil?
    @errors << "Missing git cli" if @git_cli.nil?
  end

  # apply patch (moved from model)
  def apply_patch!
    rendered = @review.rendered_code.to_s
    if rendered.blank?
      @errors << "rendered_code cannot be blank"
      @review.update!(apply_status: :failed)
      return false
    end

    line_at = @occurrence.line_at.to_i
    s = @occurrence.line_char_start&.to_i
    e = @occurrence.line_char_end&.to_i # EXCLUSIVE

    if line_at <= 0 || s.nil? || e.nil? || s.negative? || e < s
      @errors << "Invalid position info (line_at=#{@occurrence.line_at}, start=#{s}, end=#{e})"
      @review.update!(apply_status: :failed)
      return false
    end

    abs = @file.absolute_path.to_s
    content = @file.raw_content.to_s

    if content.blank?
      @errors << "File content is empty or unreadable (#{@file.path})"
      @review.update!(apply_status: :failed)
      return false
    end

    lines = content.lines
    idx = line_at - 1

    if idx.negative? || idx >= lines.length
      @errors << "line_at #{line_at} is out of file range (total lines: #{lines.length})"
      @review.update!(apply_status: :failed)
      return false
    end

    line = lines[idx].to_s
    if s > line.length
      return conflict!("Start index #{s} exceeds line length #{line.length}")
    end

    e = [e, line.length].min

    expected_old = @occurrence.matched_text.to_s
    actual_seg = line[s...e].to_s

    # conflict judge rule
    if actual_seg != expected_old
      @errors << "Conflict detected: file content has changed since scan"
      @errors << "Expected: #{expected_old.inspect}"
      @errors << "Actual:   #{actual_seg.inspect}"
      @review.update!(apply_status: :conflict)
      return false
    end

    # apply patch
    line[s...e] = rendered
    lines[idx] = line
    new_content = lines.join

    begin
      tmp = "#{abs}.tmp.#{Process.pid}.#{SecureRandom.hex(6)}"
      File.open(tmp, "wb") { |f| f.write(new_content) }
      File.rename(tmp, abs)

      @review.update!(apply_status: :applied)
      true
    rescue StandardError => ex
      @errors << "Failed to write file: #{ex.message}"
      @review.update!(apply_status: :failed)
      false
    ensure
      begin
        File.delete(tmp) if defined?(tmp) && tmp.present? && File.exist?(tmp)
      rescue StandardError
        # ignore
      end
    end
  end

  def update_review_status_approved!
    @review.update!(status: :approved)
    true
  rescue StandardError => e
    @errors << "Failed to update review status: #{e.message}"
    false
  end

  # all OccurrenceReviews for this file are approved?
  def all_reviews_for_file_approved?
    OccurrenceReview
      .joins(:occurrence)
      .where(occurrences: { repository_file_id: @file.id })
      .where.not(status: OccurrenceReview.statuses[:approved])
      .none?
  end

  def occurrence_review_ids_for_file
    OccurrenceReview
      .joins(:occurrence)
      .where(occurrences: { repository_file_id: @file.id })
      .order(:id)
      .pluck(:id)
  end

  def build_commit_message
    ids_str = occurrence_review_ids_for_file.join(",")
    "pattern-patcher(repo=#{@repository.name}) file=#{@file.path} occurrence_review_ids=[#{ids_str}]"
  end

  def success_message
    if @committed
      "Code change was successfully applied, staged, and committed (file-only)."
    else
      "Code change was successfully applied and staged. Waiting for other reviews in this file to be approved before committing."
    end
  end

  def conflict!(reason)
    @errors << "Conflict: #{reason}"
    @review.update!(apply_status: :conflict)
    false
  end

  # reserved hook
  def post_patch(_review)
    # noop
  end

  def fail_result
    Result.new(ok?: false, message: nil, errors: @errors.uniq, committed: false)
  end
end