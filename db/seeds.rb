# db/seeds.rb

if LexicalPattern.count.zero?
  LexicalPattern.create!(
    name: "Chinese inside single quotes",
    language: "ruby",
    enabled: true,
    pattern: %q{/'[^']*[\u4e00-\u9fff]+[^']*'/},
  )
  LexicalPattern.create!(
    name: "Chinese inside double quotes",
    language: "ruby",
    enabled: false,
    pattern: %q{/"[^"]*[\u4e00-\u9fff]+[^"]*"/},
  )
end

if LexemeProcessor.count.zero?
  LexemeProcessor.create!(
    name: "Localize Rails",
    key: "localize_rails",
    entrypoint: "LocalizeRails",
    default_config: {
      use_llm: true,
      llm_provider: "openai",
      llm_model: "gpt-4o",
      batch_token_limit: 300,
      key_prefix: "gpt_trans",
    },
    output_schema: {
      processed_text: "string",
      i18n_key: "string",
      locale: "string",
    },
  )
end
