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
    @git_cli = @repository.git_cli
    raw_content = @git_cli.read_file(@repo_file.blob_sha).to_s
    return 0 if raw_content.empty?

    # Normalize + build mapping helpers (file-level)
    @mapper = Support::FileByteOffsets.build(raw_content)
    @content = @mapper.content
    @lines   = @mapper.lines

    @regex = @pattern.compiled_regex
    @occ_created = 0

    is_file_mode? ? scan_whole_file! : scan_by_line!
    @occ_created
  end

  private

  def is_file_mode?
    snapshot = @scan_run.pattern_snapshot
    return false unless snapshot.is_a?(Hash)

    scan_mode = snapshot.fetch('scan_mode')
    return false unless scan_mode.present?

    scan_mode == 'file_mode'
  end


  # Scan modes
  # Line mode:
  # - MatchData begin/end are line-local char indices
  # - Convert to file-level char indices via accumulating file_char_base
  # - Then use @mapper.char_to_byte(file_char_idx) to get file-level byte offsets
  def scan_by_line!
    file_char_base = 0
    @lines.each_with_index do |line, idx|
      line_no = idx + 1
      line.to_enum(:scan, @regex).each do
        m = Regexp.last_match
        next unless m

        matched_text = m[0].to_s
        next if matched_text.empty?

        line_char_start = m.begin(0)
        line_char_end   = m.end(0) # exclusive
        file_char_start = file_char_base + line_char_start
        file_char_end   = file_char_base + line_char_end
        byte_start = @mapper.char_to_byte(file_char_start)
        byte_end   = @mapper.char_to_byte(file_char_end)

        lexeme = find_or_create_lexeme_from_raw!(matched_text)
        create_occurrence!(
          lexeme: lexeme,
          matched_text: matched_text,
          line_at: line_no,
          line_char_start: line_char_start,
          line_char_end: line_char_end,
          byte_start: byte_start,
          byte_end: byte_end,
          context: line
        )
      end

      # IMPORTANT: advance by char count (not bytes)
      file_char_base += line.each_char.count
    end
  end

  # File mode:
  # - MatchData begin/end are file-level char indices
  # - Use mapper for both line locate and byte offsets
  def scan_whole_file!
    @content.to_enum(:scan, @regex).each do
      m = Regexp.last_match
      next unless m

      matched_text = m[0].to_s
      next if matched_text.empty?

      start_char = m.begin(0)
      end_char   = m.end(0) # exclusive
      byte_start = @mapper.char_to_byte(start_char)
      byte_end   = @mapper.char_to_byte(end_char)
      line_at, line_char_start, line_char_end =
        @mapper.locate_line_and_char(start_char, end_char)
      context = @mapper.line_text(line_at)
      lexeme = find_or_create_lexeme_from_raw!(matched_text)

      create_occurrence!(
        lexeme: lexeme,
        matched_text: matched_text,
        line_at: line_at,
        line_char_start: line_char_start,
        line_char_end: line_char_end,
        byte_start: byte_start,
        byte_end: byte_end,
        context: context
      )
    end
  end


  # Occurrence create (dedupe by match_fingerprint)
  # Global unique:
  # match_fingerprint = sha_digest("#{repository_file_id}:#{byte_start}:#{byte_end}:#{lexeme_id}")
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
    fp_source = "#{@repo_file.id}:#{byte_start}:#{byte_end}:#{lexeme.id}"
    fingerprint = Lexeme.sha_digest(fp_source)

    occ =
      Occurrence.find_or_initialize_by(match_fingerprint: fingerprint) do |o|
        o.scan_run_id        = @scan_run.id
        o.lexeme_id          = lexeme.id
        o.lexical_pattern_id = @pattern.id
        o.repository_file_id = @repo_file.id
        o.line_at         = line_at
        o.line_char_start = line_char_start
        o.line_char_end   = line_char_end
        o.byte_start      = byte_start
        o.byte_end        = byte_end
        o.matched_text    = matched_text
        o.context         = context.to_s
        o.status          = "unprocessed"
      end

    if occ.new_record?
      occ.save!
      @occ_created += 1
      return occ
    end

    # 已存在：不重置 status（避免覆盖人工 review）
    # 但可以修正定位字段/上下文
    changed = false

    if occ.line_at != line_at
      occ.line_at = line_at
      changed = true
    end
    if occ.line_char_start != line_char_start
      occ.line_char_start = line_char_start
      changed = true
    end
    if occ.line_char_end != line_char_end
      occ.line_char_end = line_char_end
      changed = true
    end
    if occ.byte_start != byte_start
      occ.byte_start = byte_start
      changed = true
    end
    if occ.byte_end != byte_end
      occ.byte_end = byte_end
      changed = true
    end
    if occ.context.to_s != context.to_s
      occ.context = context.to_s
      changed = true
    end
    # 保证 scan_run_id 仍然满足 NOT NULL
    if occ.scan_run_id != @scan_run.id
      occ.scan_run_id = @scan_run.id
      changed = true
    end

    occ.save! if changed
    occ
  end


  # Lexeme normalization (extracted)
  def find_or_create_lexeme_from_raw!(raw)
    normalized, meta = Support::LexemeNormalizer.normalize(raw)
    fingerprint = Lexeme.sha_digest(normalized)

    Lexeme.find_or_create_by!(fingerprint: fingerprint) do |lx|
      lx.source_text     = raw
      lx.normalized_text = normalized
      lx.metadata        = meta
    end
  end
end