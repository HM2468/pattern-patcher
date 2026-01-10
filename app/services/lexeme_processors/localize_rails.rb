# frozen_string_literal: true

# app/services/lexeme_processors/localize_rails.rb
module LexemeProcessors
  class LocalizeRails < BaseProcessor
    # lex_arr: [{id:, normalized_text:, metadata:}]
    # return: [{id:, output_json:, metadata:}]
    def run_process(lex_arr: [])
      lex_arr.map do |item|
        lexeme_id = item.fetch(:id)
        text = item.fetch(:normalized_text).to_s
        simulate_external_call!
        locale = config.fetch("locale", "en")
        translated = fake_translate(text)
        {
          id: lexeme_id,
          output_json: {
            "processed_text" => translated,
            "i18n_key" => fake_key,
            "locale" => locale,
          },
          metadata: {
            "provider" => config["provider"],
            "model" => config["model"],
          }.compact,
        }
      end
    end

    def generate_rendered_code(
        config: {},
        lexeme_metadata: {},
        lps_output: {},
        file_path: ""
      )
      full_key = get_full_key(
        config: config,
        lps_output: lps_output,
        file_path: file_path
      )

      # 处理插值参数
      # {"interpolations" =>
      #   {"params1" => "user_display",
      #   "params2" => "target_user.username",
      #   "params3" => "project.path_with_namespace",
      #   "params4" => "UsersProject::MEMBER_NAMES[access_level]"}}
      # 期望 interpolation 结构：
      # {"params1"=>"user_display","params2"=>"target_user.username",...}
      interpolation = lexeme_metadata["interpolations"]
      params_code = ""
      if interpolation.present?
        pairs = interpolation.map do |k, v|
          "#{k}: #{v}"
        end
        params_code = ", #{pairs.join(', ')}"
      end
      rendered_code = "I18n.t(\"#{full_key}\"#{params_code})"
      metadata = { full_key: full_key}
      [rendered_code, metadata]
    end

    private

    def get_full_key(
        config: {},
        lps_output: {},
        file_path: ""
      )
      key_prefix = config.fetch("key_prefix", nil)
      last_key = lps_output["i18n_key"]

      pathkey_arr = file_path.to_s.split("/")
      filename = pathkey_arr.pop
      file_sha = ::Lexeme.sha_digest(file_path)[0..6]
      pathkey_arr.reject! { |e| e == "app" }
      pathkey_arr << file_sha
      pathkey_arr << last_key
      prefix_key = config.fetch("key_prefix", nil)
      pathkey_arr.unshift(prefix_key) if prefix_key.present?
      full_key = pathkey_arr.join(".")
      full_key
    end

    def simulate_external_call!
      sleep(rand(0.05..0.25))
    end

    def fake_translate(text)
      Faker::Lorem.paragraph(sentence_count: 3)
    end

    def fake_key
      # 短 key：word_word_xxxx
      a = %w[alpha beta gamma delta omega quick bright silent].sample
      b = %w[fox river moon cloud stone leaf].sample
      c = rand(1000..9999)
      "#{a}_#{b}_#{c}"
    end
  end
end
