# app/services/occurrence_review_diff_batch.rb
# frozen_string_literal: true

class DiffBatch
  # 返回：{ review_id => GithubLikeDiff instance }
  def self.build(reviews, context_lines: 3)
    new(reviews, context_lines: context_lines).build
  end

  def initialize(reviews, context_lines:)
    @reviews = Array(reviews)
    @context_lines = context_lines.to_i
    @raw_lines_cache = {} # key: [repo_id, blob_sha] => raw_lines(Array<String>)
  end

  def build
    diffs = {}

    # reviews 已经 includes occurrence -> repository_file -> repository
    @reviews.group_by { |r| r.occurrence&.repository_file }.each do |file, file_reviews|
      next if file.nil?

      repo = file.repository
      raw_lines = raw_lines_for(repo, file.blob_sha)

      file_reviews.each do |review|
        occ = review.occurrence
        next if occ.nil?

        old_line_from_blob, old_line_highlighted, new_line_highlighted =
          compute_old_and_new_line_highlighted(raw_lines, occ, review)

        diffs[review.id] = GithubLikeDiff.new(
          path: file.path,
          raw_lines: raw_lines,
          target_lineno: occ.line_at,
          old_line_override: old_line_highlighted,
          old_line_override: old_line_highlighted,
          new_line: new_line_highlighted,
          context_lines: @context_lines
        )
      end
    end

    diffs
  end

  private

  def raw_lines_for(repo, blob_sha)
    key = [repo.id, blob_sha]
    return @raw_lines_cache[key] if @raw_lines_cache.key?(key)

    content = repo.git_cli.read_file(blob_sha).to_s
    # GithubLikeDiff 期望 raw_lines 不带换行
    @raw_lines_cache[key] = content.lines.map { |l| l.chomp("\n").chomp("\r") }
  end

  # 让 DiffBatch 生成的 old/new 行与 OccurrenceReviewsController#show 完全一致：
  # - old_line_override / new_line 使用“带高亮的 HTML span”
  # - char range 对齐 blob 原始行
  def compute_old_and_new_line_highlighted(raw_lines, occ, review)
    idx = [occ.line_at.to_i - 1, 0].max
    idx = [idx, raw_lines.length - 1].min if raw_lines.any?
    old_line_from_blob = raw_lines[idx].to_s

    # old: deletion highlight
    old_line_highlighted =
      if occ.line_char_start && occ.line_char_end
        occ.context = old_line_from_blob if occ.respond_to?(:context=)
        occ.highlighted_deletion.to_s
      else
        ERB::Util.html_escape(old_line_from_blob)
      end

    # new: addition highlight (rendered_code)
    new_line_highlighted =
      if review.rendered_code.present? && occ.line_char_start && occ.line_char_end
        occ.context = old_line_from_blob if occ.respond_to?(:context=)
        occ.occurrence_review = review if occ.respond_to?(:occurrence_review=)
        occ.highlighted_addition.to_s
      else
        ERB::Util.html_escape(old_line_from_blob)
      end

    [old_line_from_blob, old_line_highlighted, new_line_highlighted]
  end
end