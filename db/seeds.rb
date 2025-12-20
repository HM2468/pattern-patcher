# db/seeds.rb
# Seeds for LexicalPattern
# Note:
# - pattern MUST be a Ruby regex literal string: /.../flags
# - If body contains '/', it must be escaped as '\/'
# - Allowed flags: i m x

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
    # Matches: '...中文...' (single-line)
    pattern: "/'[^\\n']*\\p{Han}+[^\\n']*'/"
  },
  {
    name: "Chinese inside double quotes (single-line)",
    language: "ruby",
    pattern_type: "string_literal",
    priority: 11,
    enabled: true,
    # Matches: \"...中文...\" (single-line)
    pattern: "/\\\"[^\\n\\\"]*\\p{Han}+[^\\n\\\"]*\\\"/"
  },

  # Optional: handle JS/TS string literals (single-line)
  {
    name: "Chinese inside single quotes (JS/TS, single-line)",
    language: "js",
    pattern_type: "string_literal",
    priority: 12,
    enabled: true,
    pattern: "/'[^\\n']*\\p{Han}+[^\\n']*'/"
  },
  {
    name: "Chinese inside double quotes (JS/TS, single-line)",
    language: "js",
    pattern_type: "string_literal",
    priority: 13,
    enabled: true,
    pattern: "/\\\"[^\\n\\\"]*\\p{Han}+[^\\n\\\"]*\\\"/"
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
    pattern: "/<%=([^\\n%]|%(?!>))*\\p{Han}+([^\\n%]|%(?!>))*%>/"
  },
  {
    name: "Chinese inside ERB tags <% ... %> (single-line)",
    language: "erb",
    pattern_type: "template",
    priority: 21,
    enabled: true,
    pattern: "/<%([^\\n%]|%(?!>))*\\p{Han}+([^\\n%]|%(?!>))*%>/"
  },
  {
    name: "Chinese inside moustache templates {{ ... }} (single-line)",
    language: "generic",
    pattern_type: "template",
    priority: 22,
    enabled: true,
    pattern: "/\\{\\{[^\\n}]*\\p{Han}+[^\\n}]*\\}\\}/"
  },

  # ------------------------------------------------------------
  # Stage 3: structured code snippets (optional helper)
  # ------------------------------------------------------------
  {
    name: "Detect I18n.t('...') key (Ruby)",
    language: "ruby",
    pattern_type: "code",
    priority: 40,
    enabled: true,
    pattern: "/(?:I18n\\.)?t\\(\\s*['\\\"]([A-Za-z0-9_\\-.]+)['\\\"][^\\)]*\\)/"
  },

  # ------------------------------------------------------------
  # Stage 4: open mixed (catch-all / last)
  # ------------------------------------------------------------
  {
    name: "Open mixed text containing Chinese or CJK punctuation (single-line)",
    language: "generic",
    pattern_type: "code",
    priority: 80,
    enabled: true,
    # Use /.../x for readability.
    # IMPORTANT: all '/' inside body are escaped as '\/'
    pattern: <<~'REGEX_LITERAL'.strip
      /
      [A-Za-z0-9.]*                                   # optional leading ascii
      (?:\\p{Han}|[（）【】「」《》；：、:()\/+丨\\u00A0-])+   # must contain Han or allowed punct
      [／!！:：；?？（）【】「」《》“”·@,，。.、%=+\\-~～\\p{Han}A-Za-z0-9\/()丨\\u00A0 ]*
      /x
    REGEX_LITERAL
  },

  {
    name: "Mostly Chinese phrase with common punctuation (single-line)",
    language: "generic",
    pattern_type: "code",
    priority: 81,
    enabled: true,
    # NOTE: '/' inside body must be escaped as '\/'
    pattern: "/\\p{Han}+[\\p{Han}0-9A-Za-z（）【】「」《》。，、；：:!?！？\\- _\\/\\s]*/"
  },

  # ------------------------------------------------------------
  # Stage 5: comments (optional runs)
  # ------------------------------------------------------------
  {
    name: "Chinese in Ruby comments (# ... , single-line)",
    language: "ruby",
    pattern_type: "comment",
    priority: 200,
    enabled: false,
    pattern: "/#[^\\n]*\\p{Han}+[^\\n]*$/"
  },
  {
    name: "Chinese in JS/TS line comments (// ... , single-line)",
    language: "js",
    pattern_type: "comment",
    priority: 201,
    enabled: false,
    # NOTE: '//' must be escaped to '\/\/' inside /.../
    pattern: "/\\/\\/[^\\n]*\\p{Han}+[^\\n]*$/"
  }
]

patterns.each do |attrs|
  record = LexicalPattern.find_or_initialize_by(name: attrs[:name])
  record.assign_attributes(attrs)
  record.save!
end

puts "Seeded #{patterns.size} lexical patterns."