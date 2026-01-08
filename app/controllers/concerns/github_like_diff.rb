# app/controllers/concerns/github_like_diff.rb
# frozen_string_literal: true

class GithubLikeDiff
  Row = Struct.new(:type, :old_lineno, :new_lineno, :content, keyword_init: true)
  # type: :hunk, :context, :del, :add

  attr_reader :path, :additions, :deletions, :hunk_header, :rows

  # raw_lines: 原文件按行 split 后数组（不带 \n）
  # target_lineno: occurrence.line_at (1-based)
  # new_line: 替换后的整行文本（不带 \n）
  def initialize(path:, raw_lines:, target_lineno:, new_line:, context_lines: 3)
    @path = path
    @raw_lines = raw_lines
    @target_lineno = target_lineno.to_i
    @new_line = (new_line || "").to_s
    @context_lines = context_lines.to_i
    build!
  end

  private

  def build!
    idx = @target_lineno - 1
    idx = 0 if idx.negative?
    idx = @raw_lines.length - 1 if @raw_lines.any? && idx >= @raw_lines.length

    old_line = @raw_lines[idx].to_s

    start_idx = [idx - @context_lines, 0].max
    end_idx   = [idx + @context_lines, @raw_lines.length - 1].min

    changed = normalize(old_line) != normalize(@new_line)

    # GitHub 风格：删除一行 + 增加一行（两行展示）
    @additions = changed ? 1 : 0
    @deletions = changed ? 1 : 0

    old_count = end_idx - start_idx + 1
    new_count = old_count

    @hunk_header = "@@ -#{start_idx + 1},#{old_count} +#{start_idx + 1},#{new_count} @@"

    @rows = []
    @rows << Row.new(type: :hunk, old_lineno: nil, new_lineno: nil, content: @hunk_header)

    (start_idx..end_idx).each do |i|
      if i == idx && changed
        # deletion row
        @rows << Row.new(type: :del, old_lineno: i + 1, new_lineno: nil, content: @raw_lines[i].to_s)
        # addition row
        @rows << Row.new(type: :add, old_lineno: nil, new_lineno: i + 1, content: @new_line)
      else
        @rows << Row.new(type: :context, old_lineno: i + 1, new_lineno: i + 1, content: @raw_lines[i].to_s)
      end
    end
  end

  def normalize(s)
    s.to_s.gsub("\r\n", "\n").chomp
  end
end