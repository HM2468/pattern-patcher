# app/services/occurrence_review_diff_batch.rb
# frozen_string_literal: true

class OccurrenceReviewDiffBatch
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
    # 这里的 reviews 已经 includes 过 occurrence -> repository_file -> repository
    diffs = {}

    # ✅ 按 repository_file 聚合：同文件只 read_file 一次
    @reviews.group_by { |r| r.occurrence&.repository_file }.each do |file, file_reviews|
      next if file.nil?

      repo = file.repository
      raw_lines = raw_lines_for(repo, file.blob_sha)

      file_reviews.each do |review|
        occ = review.occurrence
        next if occ.nil?

        old_line_from_blob, new_line = compute_old_and_new_line(raw_lines, occ, review)

        diffs[review.id] = GithubLikeDiff.new(
          path: file.path,
          raw_lines: raw_lines,
          target_lineno: occ.line_at,
          old_line_override: old_line_from_blob,
          new_line: new_line,
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

  def compute_old_and_new_line(raw_lines, occ, review)
    idx = [occ.line_at.to_i - 1, 0].max
    idx = [idx, raw_lines.length - 1].min if raw_lines.any?

    old_line = raw_lines[idx].to_s

    # 没有 rendered_code 或者缺少 range：视为无变化
    rendered = review.rendered_code.to_s
    s = occ.line_char_start
    e = occ.line_char_end

    if rendered.blank? || s.nil? || e.nil?
      return [old_line, old_line]
    end

    s = s.to_i
    e = e.to_i

    # 防御：越界就 fallback 到 snapshot 替换（至少能展示）
    if s < 0 || e < s || s > old_line.length
      return [old_line, occ.replaced_text.to_s]
    end

    prefix = old_line[0...s].to_s
    suffix = old_line[(e + 1)..].to_s
    new_line = prefix + rendered + suffix

    [old_line, new_line]
  end
end