# db/seeds.rb
# Seeds for LexicalPattern
# Principle:
# - Run "structural & bounded" patterns first (string literals, templates)
# - Run broad "catch-all" patterns last (open mixed)
# - Keep comments/docs patterns in their own stage (optional runs)

patterns = [
  # ------------------------------------------------------------
  # Stage 1: string literals (most precise boundaries)
  # ------------------------------------------------------------
  {
    name: "Chinese inside single quotes (single-line)",
    language: "ruby",
    pattern_type: "string_literal",
    priority: 10,
    enabled: true,
    # Single-line only (no \n). Matches: '...中文...'
    pattern: "'[^\\n']*\\p{Han}+[^\n']*'"
  },
  {
    name: "Chinese inside double quotes (single-line)",
    language: "ruby",
    pattern_type: "string_literal",
    priority: 11,
    enabled: true,
    # Single-line only (no \n). Matches: "...中文..."
    pattern: "\"[^\\n\\\"]*\\p{Han}+[^\n\\\"]*\""
  },

  # Optional: handle JS/TS string literals (single-line)
  {
    name: "Chinese inside single quotes (JS/TS, single-line)",
    language: "js",
    pattern_type: "string_literal",
    priority: 12,
    enabled: true,
    pattern: "'[^\\n']*\\p{Han}+[^\n']*'"
  },
  {
    name: "Chinese inside double quotes (JS/TS, single-line)",
    language: "js",
    pattern_type: "string_literal",
    priority: 13,
    enabled: true,
    pattern: "\"[^\\n\\\"]*\\p{Han}+[^\n\\\"]*\""
  },

  # ------------------------------------------------------------
  # Stage 2: templates (bounded by template delimiters)
  # ------------------------------------------------------------
  {
    name: "Chinese inside ERB output tags <%= ... %> (single-line)",
    language: "erb",
    pattern_type: "template",
    priority: 20,
    enabled: true,
    # ERB output block on a single line, must contain Han
    pattern: "<%=([^\\n%]|%(?!>))*\\p{Han}+([^\\n%]|%(?!>))*%>"
  },
  {
    name: "Chinese inside ERB tags <% ... %> (single-line)",
    language: "erb",
    pattern_type: "template",
    priority: 21,
    enabled: true,
    pattern: "<%([^\\n%]|%(?!>))*\\p{Han}+([^\\n%]|%(?!>))*%>"
  },
  {
    name: "Chinese inside moustache templates {{ ... }} (single-line)",
    language: "generic",
    pattern_type: "template",
    priority: 22,
    enabled: true,
    pattern: "\\{\\{[^\\n}]*\\p{Han}+[^\\n}]*\\}\\}"
  },

  # ------------------------------------------------------------
  # Stage 3: structured code snippets (optional)
  # (These are NOT for extracting Chinese, but can help detect
  # already-i18n’ed code or avoid double work in residual reports.)
  # ------------------------------------------------------------
  {
    name: "Detect I18n.t('...') key (Ruby)",
    language: "ruby",
    pattern_type: "code",
    priority: 40,
    enabled: true,
    # Captures the key part inside I18n.t("xxx") / t('xxx')
    # Use as a helper (e.g., for reporting), not as a Chinese extractor.
    pattern: "(?:I18n\\.)?t\\(\\s*['\\\"]([A-Za-z0-9_\\-.]+)['\\\"][^\\)]*\\)"
  },

  # ------------------------------------------------------------
  # Stage 4: open mixed (catch-all / last)
  # Goal: avoid missing Chinese, even if noisy.
  # Keep it single-line to match your scanning model.
  # ------------------------------------------------------------
  {
    name: "Open mixed text containing Chinese or CJK punctuation (single-line)",
    language: "generic",
    pattern_type: "code",
    priority: 80,
    enabled: true,
    # Intentionally broad; should run after all bounded patterns.
    # - \p{Han} matches Han ideographs
    # - \u00A0 is NBSP
    # - Single-line only (no newlines)
    pattern: <<~'REGEX'.strip
      [A-Za-z0-9.]*                                   # optional leading ascii
      (?:\\p{Han}|[（）【】「」《》；：、:()/+丨\\u00A0-])+   # must contain Han or allowed punct
      [／!！:：；?？（）【】「」《》“”·@,，。.、%=+\\-~～\\p{Han}A-Za-z0-9/()丨\\u00A0 ]*
    REGEX
  },

  # A slightly narrower catch-all for "mostly Chinese short phrases"
  {
    name: "Mostly Chinese phrase with common punctuation (single-line)",
    language: "generic",
    pattern_type: "code",
    priority: 81,
    enabled: true,
    pattern: "\\p{Han}+[\\p{Han}0-9A-Za-z（）【】「」《》。，、；：:!?！？\\-_/\\s]*"
  },

  # ------------------------------------------------------------
  # Stage 5: comments (run separately; optional)
  # ------------------------------------------------------------
  {
    name: "Chinese in Ruby comments (# ... , single-line)",
    language: "ruby",
    pattern_type: "comment",
    priority: 200,
    enabled: false,
    # Single-line Ruby comment containing Han
    pattern: "#[^\\n]*\\p{Han}+[^\\n]*$"
  },
  {
    name: "Chinese in JS/TS line comments (// ... , single-line)",
    language: "js",
    pattern_type: "comment",
    priority: 201,
    enabled: false,
    pattern: "//[^\\n]*\\p{Han}+[^\\n]*$"
  }
]

patterns.each do |attrs|
  record = LexicalPattern.find_or_initialize_by(name: attrs[:name])
  record.assign_attributes(attrs)
  record.save!
end

puts "Seeded #{patterns.size} lexical patterns."