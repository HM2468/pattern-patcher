# app/services/occurrence_review_diff_batch.rb
# frozen_string_literal: true

class DiffBatch
  # records: Array<OccurrenceReview> OR Array<Occurrence>
  # 返回：{ id => GithubLikeDiff instance }
  def self.build(records, context_lines: 3)
    new(records, context_lines: context_lines).build
  end

  def initialize(records, context_lines:)
    @records = Array(records).compact
    @context_lines = context_lines.to_i
    @raw_lines_cache = {} # key: [repo_id, blob_sha] => Array<String>
  end

  def build
    diffs = {}
    return diffs if @records.empty?

    # 统一把 record 映射到 occurrence / repository_file
    groups = @records.group_by { |rec| repository_file_for(rec) }

    groups.each do |file, file_records|
      next if file.nil?

      repo = file.repository
      raw_lines = raw_lines_for(repo, file.blob_sha)

      file_records.each do |rec|
        occ = occurrence_for(rec)
        next if occ.nil?

        old_line_highlighted, new_line_highlighted =
          compute_old_and_new_line_highlighted(raw_lines, occ, rec)

        diffs[rec.id] = GithubLikeDiff.new(
          path: file.path,
          raw_lines: raw_lines,
          target_lineno: occ.line_at,
          old_line_override: old_line_highlighted,
          new_line: new_line_highlighted,
          context_lines: @context_lines
        )
      end
    end

    diffs
  end

  private

  # -------- type helpers --------

  def occurrence_for(rec)
    # OccurrenceReview -> occurrence
    # Occurrence       -> itself
    if rec.respond_to?(:occurrence)
      rec.occurrence
    else
      rec
    end
  end

  def repository_file_for(rec)
    occ = occurrence_for(rec)
    return nil if occ.nil?
    occ.repository_file
  end

  def occurrence_review_record?(rec)
    rec.respond_to?(:occurrence) && rec.respond_to?(:rendered_code)
  end

  # -------- git blob cache --------

  def raw_lines_for(repo, blob_sha)
    key = [repo.id, blob_sha]
    return @raw_lines_cache[key] if @raw_lines_cache.key?(key)

    content = repo.git_cli.read_file(blob_sha).to_s
    @raw_lines_cache[key] = content.lines.map { |l| l.chomp("\n").chomp("\r") }
  end

  # -------- highlighting builders --------
  #
  # 让 DiffBatch 生成的 old/new 行与 show 行为一致：
  # - old_line_override / new_line 使用“带高亮的 HTML span”
  # - char range 对齐 blob 原始行
  # - 传 Occurrence 时：new_line = nil
  #
  def compute_old_and_new_line_highlighted(raw_lines, occ, rec)
    old_line_from_blob = line_from_blob(raw_lines, occ.line_at)

    # old: deletion highlight（基于 matched_text / range）
    old_line_highlighted =
      if occ.line_char_start && occ.line_char_end
        s = occ.line_char_start.to_i
        e = occ.line_char_end.to_i
        highlight_range(old_line_from_blob, s, e, old_line_from_blob[s..e].to_s, "highlighted_deletion")
      else
        CGI.escapeHTML(old_line_from_blob.to_s)
      end

    # new:
    # - OccurrenceReview：addition highlight（rendered_code）
    # - Occurrence：new_line = nil
    new_line_highlighted =
      if occurrence_review_record?(rec)
        rendered = rec.rendered_code.to_s
        if rendered.present? && occ.line_char_start && occ.line_char_end
          s = occ.line_char_start.to_i
          e = occ.line_char_end.to_i
          highlight_range(old_line_from_blob, s, e, rendered, "highlighted_addition")
        else
          CGI.escapeHTML(old_line_from_blob.to_s)
        end
      else
        nil
      end

    [old_line_highlighted, new_line_highlighted]
  end

  def line_from_blob(raw_lines, target_lineno)
    idx = target_lineno.to_i - 1
    idx = 0 if idx.negative?
    idx = raw_lines.length - 1 if raw_lines.any? && idx >= raw_lines.length
    raw_lines[idx].to_s
  end

  # 将 raw_line 按 [s..e] 切片，高亮 inner_text（不一定等于 raw_line[s..e]）
  # 并对三段分别 escape，保证 HTML 安全 + char range 不受 escape 影响
  def highlight_range(raw_line, s, e, inner_text, klass)
    line = raw_line.to_s
    return CGI.escapeHTML(line) if line.empty?

    s = 0 if s.negative?
    e = s if e < s
    return CGI.escapeHTML(line) if s > line.length

    prefix = line[0...s].to_s
    suffix = line[(e + 1)..].to_s

    "#{CGI.escapeHTML(prefix)}" \
      "<span class=\"#{klass}\">#{CGI.escapeHTML(inner_text.to_s)}</span>" \
      "#{CGI.escapeHTML(suffix)}"
  end
end