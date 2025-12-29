# frozen_string_literal: true

# app/helpers/lexeme_processors_helper.rb
module LexemeProcessorsHelper
  DEFAULT_DEFAULT_CONFIG = {
    use_llm: true,
    llm_provider: "openai",
    llm_model: "gpt-4o",
    batch_token_limit: 1500,
    key_prefix: "gpt_trans",
  }.freeze

  DEFAULT_OUTPUT_SCHEMA = {
    processed_text: "string",
    i18n_key: "string",
    locale: "string",
  }.freeze

  # 给 placeholder 用：永远返回默认 JSON（pretty）
  def lexeme_processor_default_json_placeholder(field)
    data =
      case field.to_sym
      when :default_config then DEFAULT_DEFAULT_CONFIG
      when :output_schema  then DEFAULT_OUTPUT_SCHEMA
      else {}
      end

    JSON.pretty_generate(deep_stringify_keys(data))
  end

  # 给 value 用：如果记录里有值，就返回记录的 pretty JSON；否则返回 nil（让 value 为空）
  def lexeme_processor_json_value_or_nil(lexeme_processor, field)
    raw = extract_json_field(lexeme_processor, field)
    return nil unless raw.is_a?(Hash) && raw.present?

    JSON.pretty_generate(deep_stringify_keys(raw))
  end

  # 判空（nil / {} / 空 hash）
  def lexeme_processor_json_blank?(lexeme_processor, field)
    raw = extract_json_field(lexeme_processor, field)
    raw.blank? || raw == {}
  end

  private

  def extract_json_field(lexeme_processor, field)
    raw =
      case field.to_sym
      when :default_config then lexeme_processor.default_config
      when :output_schema  then lexeme_processor.output_schema
      else {}
      end

    return {} if raw.nil?

    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    raw = raw.to_h if raw.respond_to?(:to_h)

    raw.is_a?(Hash) ? raw : {}
  end

  def deep_stringify_keys(obj)
    case obj
    when Hash
      obj.each_with_object({}) do |(k, v), h|
        h[k.to_s] = deep_stringify_keys(v)
      end
    when Array
      obj.map { |v| deep_stringify_keys(v) }
    else
      obj
    end
  end
end
