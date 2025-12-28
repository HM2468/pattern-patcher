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
        key_prefix = config.fetch("key_prefix", "gpt_trans")

        translated = fake_translate(text)
        i18n_key = "#{key_prefix}.#{fake_key}"

        {
          id: lexeme_id,
          output_json: {
            "translated_text" => translated,
            "i18n_key" => i18n_key,
            "locale" => locale
          },
          metadata: {
            "provider" => config["provider"],
            "model" => config["model"]
          }.compact
        }
      end
    end

    private

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