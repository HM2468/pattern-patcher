# frozen_string_literal: true

# app/services/lexeme_processors/localize_rails.rb
module LexemeProcessors
  class LocalizeRails < BaseProcessor
    # lex_arr: [{id:, normalized_text:, metadata:}]
    # return: [{id:, output_json:, metadata:}]
    def run_process(lex_arr: [])
      return [] if lex_arr.blank?

      source_lang = (config["source_lang"] || "auto").to_s
      target_lang = (config["target_lang"] || config["locale"] || "english").to_s
      model       = (config["llm_model"] || ::Support::YamlBatchTranslator::DEFAULT_MODEL).to_s
      provider    = (config["provider"] || "openai").to_s

      input_map = ::Support::YamlBatchTranslator.build_input_yaml_map(lex_arr)
      output_map = ::Support::YamlBatchTranslator.call(
        input_map: input_map,
        source_lang: source_lang,
        target_lang: target_lang,
        model: model,
        logger: (defined?(Rails) ? Rails.logger : nil)
      )

      lex_arr.map do |item|
        lexeme_id = item.fetch(:id)
        k10       = ::Support::YamlBatchTranslator.format_id10(lexeme_id)
        one       = output_map[k10] || {}

        i18n_key  = ::Support::YamlBatchTranslator.normalize_i18n_key(one["i18n_key"])
        trans     = one["trans_text"].to_s

        i18n_key = fallback_key(item.fetch(:normalized_text).to_s) if i18n_key.blank?

        {
          id: lexeme_id,
          output_json: {
            "processed_text" => trans,
            "i18n_key" => i18n_key,
            "locale" => target_lang
          },
          metadata: {
            "provider" => provider,
            "model" => model,
            "source_lang" => source_lang,
            "target_lang" => target_lang
          }.compact
        }
      end
    end

    # Rails-specific rendered code generation
    def generate_rendered_code(config: {}, lexeme_metadata: {}, lps_output: {}, file_path: "")
      full_key = get_full_key(config: config, lps_output: lps_output, file_path: file_path)

      interpolation = lexeme_metadata["interpolations"]
      params_code = ""

      if interpolation.present?
        pairs = interpolation.map { |k, v| "#{k}: #{v}" }
        params_code = ", #{pairs.join(', ')}"
      end

      rendered_code = "I18n.t(\"#{full_key}\"#{params_code})"
      metadata = { full_key: full_key }
      [rendered_code, metadata]
    end

    private

    # Existing full_key logic (keep yours)
    def get_full_key(config: {}, lps_output: {}, file_path: "")
      last_key = lps_output["i18n_key"]

      pathkey_arr = file_path.to_s.split("/")
      _filename = pathkey_arr.pop
      file_sha = ::Lexeme.sha_digest(file_path)[0..6]
      pathkey_arr.reject! { |e| e == "app" }
      pathkey_arr << file_sha
      pathkey_arr << last_key

      prefix_key = config.fetch("key_prefix", nil)
      pathkey_arr.unshift(prefix_key) if prefix_key.present?

      pathkey_arr.join(".")
    end

    def fallback_key(text)
      base = text.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").split.reject(&:blank?).first(6)
      if base.empty?
        "msg_#{rand(1000..9999)}"
      else
        ::Support::YamlBatchTranslator.normalize_i18n_key(base.join("_"))
      end
    end
  end
end