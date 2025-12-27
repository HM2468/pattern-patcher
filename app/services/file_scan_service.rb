# frozen_string_literal: true
# app/services/file_scan_service.rb
class FileScanService
  def initialize(repository:, scan_run:, repo_file:, pattern:)
    @repository = repository
    @scan_run   = scan_run
    @repo_file  = repo_file
    @pattern    = pattern
  end

  def execute
    @git_cli      = @repository.git_cli
    @file_content = @git_cli.read_file(@repo_file.blob_sha).to_s
    @regex        = @pattern.compiled_regex
    @occ_created  = 0
    return 0 if @file_content.empty?

    # Pre-split lines for context building (keeps \n)
    @lines = @file_content.lines
    if @scan_run.scan_mode.to_s == "file"
      scan_whole_file!
    else
      scan_by_line!
    end
    @occ_created
  end

  private
  # Scan modes
  # Line mode: fast, simple offsets, but cannot match cross-line patterns
  # Uniq: scan_run_id + lexeme_id + repository_file_id + line_at + line_char_start
  def scan_by_line!
    byte_base = 0 # byte offset at the start of current line in the full file
    @lines.each_with_index do |line, idx|
      line_no = idx + 1

      line.to_enum(:scan, @regex).each do
        m = Regexp.last_match
        next unless m

        raw = m[0].to_s
        next if raw.empty?

        start_char = m.begin(0)
        end_char   = m.end(0) # exclusive

        start_byte_in_line = char_index_to_byte_index(line, start_char)
        end_byte_in_line   = char_index_to_byte_index(line, end_char)
        byte_start = byte_base + start_byte_in_line
        byte_end   = byte_base + end_byte_in_line

        lexeme = find_or_create_lexeme_from_raw!(raw)

        create_occurrence!(
          lexeme: lexeme,
          matched_text: raw,
          line_at: line_no,
          line_char_start: start_char,
          line_char_end: end_char,
          byte_start: byte_start,
          byte_end: byte_end,
          context: line
        )
      end

      byte_base += line.bytesize
    end
  end

  # File mode: supports cross-line matching. Offsets are based on full file.
  # Uniq: lexeme_id + repository_file_id + line_at + line_char_start + byte_start
  def scan_whole_file!
    @file_content.to_enum(:scan, @regex).each do
      m = Regexp.last_match
      next unless m

      raw = m[0].to_s
      next if raw.empty?

      start_char = m.begin(0)
      end_char   = m.end(0) # exclusive
      byte_start = char_index_to_byte_index(@file_content, start_char)
      byte_end   = char_index_to_byte_index(@file_content, end_char)

      line_no, line_char_start, line_char_end =
        locate_line_and_char(@file_content, start_char, end_char)

      lexeme = find_or_create_lexeme_from_raw!(raw)
      context = @lines[line_no - 1].to_s
      create_occurrence!(
        lexeme: lexeme,
        matched_text: raw,
        line_at: line_no,
        line_char_start: line_char_start,
        line_char_end: line_char_end,
        byte_start: byte_start,
        byte_end: byte_end,
        context: context
      )
    end
  end

  # Occurrence create (dedupe)
  def create_occurrence!(
    lexeme:,
    matched_text:,
    line_at:,
    line_char_start:,
    line_char_end:,
    byte_start:,
    byte_end:,
    context:
  )
    uniq_attrs = {
      lexeme_id: lexeme.id,
      repository_file_id: @repo_file.id,
      line_at: line_at,
      line_char_start: line_char_start
    }
    occ =
      Occurrence.find_or_initialize_by(uniq_attrs) do |o|
        o.lexical_pattern_id = @pattern.id
        o.scan_run_id        = @scan_run.id
        o.line_char_end      = line_char_end
        o.byte_start         = byte_start
        o.byte_end           = byte_end
        o.matched_text       = matched_text
        o.context            = context.to_s
        o.status             = "unreviewed"
      end
    @occ_created += 1 if occ.save! && occ.previously_new_record?
    occ
  end

  # Lexeme normalization
  def find_or_create_lexeme_from_raw!(raw)
    normalized, meta = normalize_matched_text(raw)
    fingerprint = Lexeme.sha_digest(normalized)

    Lexeme.find_or_create_by!(fingerprint: fingerprint) do |lx|
      lx.source_text     = raw
      lx.normalized_text = normalized
      lx.metadata        = meta
    end
  end

  # Rules:
  # - strip matching outer quotes ("..." or '...')
  # - Ruby interpolation: "#{expr}" -> "%{paramsN}" and store mapping in metadata
  def normalize_matched_text(raw)
    s = raw.to_s
    # Strip outer quotes only if they are paired and matching
    if s.length >= 2
      first = s[0]
      last  = s[-1]
      if (first == '"' && last == '"') || (first == "'" && last == "'")
        s = s[1..-2]
      end
    end

    interpolations = {}
    idx = 0
    # Pragmatic parser: "#{...}" where ... does not include "}"
    s2 = s.gsub(/#\{([^}]+)\}/) do
      idx += 1
      key = "params#{idx}"
      interpolations[key] = Regexp.last_match(1).to_s.strip
      "%{#{key}}"
    end

    metadata = {}
    metadata["interpolations"] = interpolations unless interpolations.empty?

    [s2, metadata]
  end

  # Offsets helpers
  # Convert a char-index into byte-index (end is exclusive if you pass exclusive char index).
  def char_index_to_byte_index(str, char_index)
    return 0 if char_index <= 0
    str.each_char.take(char_index).join.bytesize
  end

  # For file-mode matches, derive:
  # - line_no (1-based)
  # - line_char_start/end (exclusive end) within that line
  def locate_line_and_char(content, start_char, end_char)
    prefix = content.each_char.take(start_char).join
    line_no = prefix.count("\n") + 1

    last_nl_pos = prefix.rindex("\n") # char index within prefix
    line_start_char = last_nl_pos ? (last_nl_pos + 1) : 0

    line_char_start = start_char - line_start_char
    line_char_end   = end_char - line_start_char

    [line_no, line_char_start, line_char_end]
  end
end