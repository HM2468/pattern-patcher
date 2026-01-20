# frozen_string_literal: true
# app/services/support/yaml_batch_translator.rb
require "yaml"
require "openai"

  module Support
    class YamlBatchTranslator
      DEFAULT_MODEL = "gpt-4o-mini"

      # Public API:
      #
      # input:  Hash{"0000001234" => "source text", ...}
      # output: Hash{
      #   "0000001234" => {"i18n_key"=>"...", "trans_text"=>"..."},
      #   ...
      # }
      #
      def self.call(
        input_map:,
        source_lang:,
        target_lang:,
        model: DEFAULT_MODEL,
        logger: nil,
        temperature: 0.2
      )
        new(
          input_map: input_map,
          source_lang: source_lang,
          target_lang: target_lang,
          model: model,
          logger: logger,
          temperature: temperature
        ).call
      end

      def initialize(input_map:, source_lang:, target_lang:, model:, logger:, temperature:)
        @input_map = deep_stringify_keys(input_map || {})
        @source_lang = source_lang.to_s
        @target_lang = target_lang.to_s
        @model = model.to_s
        @logger = logger
        @temperature = temperature.to_f
      end

      def call
        return {} if @input_map.empty?

        content = translate_once!(@input_map)
        parsed = safe_load_yaml_hash!(content)
        normalize_translation_output!(parsed, @input_map)
        parsed
      end

      # -----------------------
      # Helpers for processors
      # -----------------------
      def self.format_id10(id)
        id.to_i.to_s.rjust(10, "0")
      end

      def self.build_input_yaml_map(lex_arr)
        Array(lex_arr).each_with_object({}) do |item, h|
          id  = item.fetch(:id)
          txt = item.fetch(:normalized_text).to_s
          h[format_id10(id)] = txt
        end
      end

      def self.normalize_i18n_key(key)
        s = key.to_s.strip.downcase
        s = s.gsub(/[^a-z0-9_]/, "_")
        s = s.gsub(/_+/, "_").gsub(/\A_+|_+\z/, "")
        parts = s.split("_").reject(&:empty?)
        parts.first(6).join("_")
      end

      def self.placeholders(text)
        text.to_s.scan(/%\{[a-zA-Z0-9_]+\}/).uniq
      end

      private

      def translate_once!(input_map)
        client = OpenAI::Client.new

        input_yaml = YAML.dump(input_map).sub(/\A---\s*\n/, "")

        system_prompt = <<~SYS
          You are a professional localization engine for Ruby on Rails i18n.

          Task:
          - Input is a YAML mapping: "0000001234": <source text>
          - Translate each value from SOURCE_LANG to TARGET_LANG.
          - Preserve exactly:
            - Rails interpolation placeholders like %{params1}, %{user}, etc (must remain unchanged).
            - Any HTML tags/attributes (e.g. <a href='%{params1}'>) and Markdown syntax.
            - Newlines and punctuation meaningfully.

          For each entry, also generate an "i18n_key":
          - snake_case
          - <= 6 words (segments) separated by underscore
          - concise, meaningful
          - only [a-z0-9_]

          Output MUST be valid YAML in the exact shape:

          "0000001234":
            i18n_key: example_key
            trans_text: translated text

          Do NOT wrap YAML in code fences.
        SYS

        user_prompt = <<~USR
          SOURCE_LANG: #{@source_lang}
          TARGET_LANG: #{@target_lang}

          INPUT_YAML:
          #{input_yaml}
        USR

        @logger&.info("[YamlBatchTranslator] model=#{@model} keys=#{input_map.size}")

        resp = client.chat(
          parameters: {
            model: @model,
            temperature: @temperature,
            messages: [
              { role: "system", content: system_prompt },
              { role: "user", content: user_prompt }
            ]
          }
        )

        resp.dig("choices", 0, "message", "content").to_s.strip
      end

      def safe_load_yaml_hash!(yaml_str)
        obj = YAML.safe_load(
          yaml_str,
          permitted_classes: [Date, Time],
          aliases: false
        )
        unless obj.is_a?(Hash)
          raise RuntimeError, "LLM returned invalid YAML root (expected mapping/hash)."
        end
        deep_stringify_keys(obj)
      rescue Psych::SyntaxError => e
        raise RuntimeError, "LLM returned invalid YAML: #{e.message}\n---\n#{yaml_str}"
      end

      def normalize_translation_output!(parsed, input_map)
        # Ensure every input key exists and has expected shape
        input_map.keys.each do |k10|
          v = parsed[k10]
          parsed[k10] = {} unless v.is_a?(Hash)

          parsed[k10]["i18n_key"]  = parsed[k10]["i18n_key"].to_s
          parsed[k10]["trans_text"] = parsed[k10]["trans_text"].to_s

          # 关键兜底：插值占位符不能丢
          src = input_map[k10].to_s
          dst = parsed[k10]["trans_text"].to_s
          phs = self.class.placeholders(src)
          if phs.any? && !phs.all? { |ph| dst.include?(ph) }
            parsed[k10]["trans_text"] = src
          end

          parsed[k10]["i18n_key"] = self.class.normalize_i18n_key(parsed[k10]["i18n_key"])
        end

        # Drop extra keys from model output
        parsed.slice!(*input_map.keys)
      end

      def deep_stringify_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(k, v), h|
            h[k.to_s] = deep_stringify_keys(v)
          end
        when Array
          obj.map { |e| deep_stringify_keys(e) }
        else
          obj
        end
      end
    end
  end