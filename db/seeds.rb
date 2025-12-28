# db/seeds.rb
LexicalPattern.create!(
  name: "Chinese inside single quotes",
  language: "ruby",
  priority: 10,
  enabled: true,
  pattern: "/'[^']*[\u4e00-\u9fff]+[^']*'/",
)
LexicalPattern.create!(
  name: "Chinese inside double quotes",
  language: "ruby",
  priority: 10,
  enabled: false,
  pattern: '/"[^"]*[\u4e00-\u9fff]+[^"]*"/',
)
LexemeProcess.create!(
  name: "Localize Rails",
  key: "localize_rails",
  entrypoint: "LexemeProcessors::LocalizeRails",
  default_config: {
    "target_locale" => "en",
    "provider" => "openai",
    "model" => "gpt-4o",
    "key_prefix" => "rails",
  },
  output_schema: {
    "translated_text" => "string",
    "locale" => "string",
    "suggested_i18n_key" => "string",
  },
)
