# frozen_string_literal: true

module Support
  module LexemeNormalizer
    module_function

    def normalize(raw)
      s = raw.to_s
      s = strip_outer_quotes(s)
      replace_ruby_interpolations(s)
    end

    def strip_outer_quotes(s)
      return s if s.length < 2
      first = s[0]
      last  = s[-1]
      if (first == '"' && last == '"') || (first == "'" && last == "'")
        s[1..-2]
      else
        s
      end
    end

    def replace_ruby_interpolations(s)
      interpolations = {}
      idx = 0

      out = s.gsub(/#\{([^}]+)\}/) do
        idx += 1
        key = "params#{idx}"
        interpolations[key] = Regexp.last_match(1).to_s.strip
        "%{#{key}}"
      end

      meta = {}
      meta["interpolations"] = interpolations unless interpolations.empty?
      [out, meta]
    end
  end
end