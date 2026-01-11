# app/controllers/concerns/github_like_diff.rb
# frozen_string_literal: true

class GithubLikeDiff
  Row = Struct.new(:type, :old_lineno, :new_lineno, :content, keyword_init: true)
  # type: :hunk, :context, :del, :add

  attr_reader :path, :additions, :deletions, :hunk_header, :rows

  # raw_lines: original file split into lines (each line WITHOUT "\n")
  # target_lineno: 1-based
  # new_line: the full replacement line (WITHOUT "\n"); can be nil (meaning "no new line")
  # old_line_override: if provided, used as the "old line" shown in the diff
  def initialize(path:, raw_lines:, target_lineno:, new_line:, context_lines: 3, old_line_override: nil)
    @path = path
    @raw_lines = raw_lines || []
    @target_lineno = target_lineno.to_i
    @new_line = new_line # keep nil as nil (important for Occurrence-only diffs)
    @context_lines = context_lines.to_i
    @old_line_override = old_line_override
    build!
  end

  private

  def build!
    idx = @target_lineno - 1
    idx = 0 if idx.negative?
    idx = @raw_lines.length - 1 if @raw_lines.any? && idx >= @raw_lines.length

    old_line = (@old_line_override || @raw_lines[idx]).to_s
    old_line_norm = normalize(old_line)

    new_line_norm = @new_line.nil? ? nil : normalize(@new_line)
    changed = !new_line_norm.nil? && (old_line_norm != new_line_norm)

    @additions = changed ? 1 : 0
    @deletions = changed ? 1 : 0

    start_idx = [idx - @context_lines, 0].max
    end_idx   = [idx + @context_lines, @raw_lines.length - 1].min

    old_count = end_idx - start_idx + 1
    new_count = old_count

    @hunk_header = "@@ -#{start_idx + 1},#{old_count} +#{start_idx + 1},#{new_count} @@"

    @rows = []
    @rows << Row.new(type: :hunk, old_lineno: nil, new_lineno: nil, content: @hunk_header)

    (start_idx..end_idx).each do |i|
      line = @raw_lines[i].to_s

      if i == idx && changed
        @rows << Row.new(type: :del, old_lineno: i + 1, new_lineno: nil, content: old_line)
        @rows << Row.new(type: :add, old_lineno: nil, new_lineno: i + 1, content: @new_line)
      else
        @rows << Row.new(type: :context, old_lineno: i + 1, new_lineno: i + 1, content: line)
      end
    end
  end

  def normalize(s)
    s.to_s.gsub("\r\n", "\n").chomp
  end
end