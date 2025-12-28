# app/models/concerns/lexeme_processors/localize_rails.rb
# frozen_string_literal: true

module LexemeProcessors
  class LocalizeRails < Base
    # 模拟 LLM 翻译：
    # - 随机 sleep，模拟网络/模型延迟
    # - 用 Faker 生成“翻译结果”
    # - 用随机短语生成 i18n key
    #
    # 输出格式需符合 lexeme_processors.output_schema
    #
    # output_json:
    # {
    #   "translated_text" => "...",
    #   "i18n_key"        => "...",
    #   "locale"          => "en"
    # }
    #
    # metadata:
    # {
    #   "provider" => "openai",
    #   "model"    => "gpt-4o",
    #   "latency"  => 0.42
    # }

    def call(lexeme)
      simulate_llm_latency!

      translated_text = fake_translation(lexeme.normalized_text)
      i18n_key        = build_i18n_key(lexeme)

      {
        output_json: {
          "translated_text" => translated_text,
          "i18n_key"        => i18n_key,
          "locale"          => target_locale
        },
        metadata: {
          "provider" => config["provider"],
          "model"    => config["model"],
          "latency"  => @last_latency
        }
      }
    end

    private

    def simulate_llm_latency!
      @last_latency = rand(0.2..1.2).round(2)
      sleep(@last_latency)
    end

    def fake_translation(source_text)
      # 生成一段“像英文翻译”的假文本
      # 示例："User profile updated successfully"
      Faker::Lorem
        .sentence(word_count: rand(4..8))
        .chomp(".")
        .capitalize
    end

    def build_i18n_key(lexeme)
      prefix = config.fetch("key_prefix", "gpt_trans")

      # 使用随机短语，避免和 fingerprint 强绑定，便于演示
      phrase =
        Faker::Lorem
          .words(number: rand(2..4))
          .join("_")
          .downcase

      "#{prefix}.#{phrase}"
    end

    def target_locale
      config.fetch("locale", "en")
    end
  end
end