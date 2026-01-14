# app/controllers/concerns/batch_diff.rb
# frozen_string_literal: true

class DiffBatch
  # records: Array<OccurrenceReview> OR Array<Occurrence>
  # returns: { record_id => GithubLikeDiff instance }
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

    # Group by repository_file so we only read each blob once
    @records.group_by { |rec| repository_file_for(rec) }.each do |file, file_records|
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
          new_line: new_line_highlighted, # nil when rec is an Occurrence
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
    rec.respond_to?(:occurrence) ? rec.occurrence : rec
  end

  def repository_file_for(rec)
    occ = occurrence_for(rec)
    occ&.repository_file
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
  # Ensures DiffBatch produces the same old/new line behavior as your show actions:
  # - old_line_override / new_line contain HTML with <span class="..."> for inline highlight
  # - char range is aligned to the blob's actual line text
  # - when passing Occurrence: new_line is nil
  #
  # IMPORTANT:
  # - line_char_end is treated as EXCLUSIVE (Ruby slice style: [s...e])
  #
  def compute_old_and_new_line_highlighted(raw_lines, occ, rec)
    old_line_from_blob = line_from_blob(raw_lines, occ.line_at)

    # old: deletion highlight (based on matched_text and [start, end) range)
    old_line_highlighted =
      if occ.line_char_start && occ.line_char_end
        s = occ.line_char_start.to_i
        e = occ.line_char_end.to_i # EXCLUSIVE
        inner = occ.matched_text.to_s.presence || old_line_from_blob[s...e].to_s
        highlight_range_exclusive(old_line_from_blob, s, e, inner, "highlighted_deletion")
      else
        CGI.escapeHTML(old_line_from_blob.to_s)
      end

    # new:
    # - OccurrenceReview: addition highlight (rendered_code)
    # - Occurrence: new_line = nil
    new_line_highlighted =
      if occurrence_review_record?(rec)
        rendered = rec.rendered_code.to_s
        if rendered.present? && occ.line_char_start && occ.line_char_end
          s = occ.line_char_start.to_i
          e = occ.line_char_end.to_i # EXCLUSIVE
          highlight_range_exclusive(old_line_from_blob, s, e, rendered, "highlighted_addition")
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

  # Highlight the segment defined by [s, e) (end is EXCLUSIVE).
  # inner_text does not have to equal raw_line[s...e] (e.g. can come from matched_text/rendered_code).
  # Escapes prefix/inner/suffix separately for HTML safety.
  def highlight_range_exclusive(raw_line, s, e, inner_text, klass)
    line = raw_line.to_s
    return CGI.escapeHTML(line) if line.empty?

    s = 0 if s.negative?
    e = s if e < s
    return CGI.escapeHTML(line) if s > line.length

    # Clamp end (exclusive) into [s, line.length]
    e = [e, line.length].min

    prefix = line[0...s].to_s
    suffix = line[e..].to_s # because e is EXCLUSIVE

    "#{CGI.escapeHTML(prefix)}" \
      "<span class=\"#{klass}\">#{CGI.escapeHTML(inner_text.to_s)}</span>" \
      "#{CGI.escapeHTML(suffix)}"
  end
end