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
LexemeProcessor.create!(
  name: "Localize Rails",
  key: "localize_rails",
  entrypoint: "LexemeProcessors::LocalizeRails",
  default_config: {
    "provider" => "openai",
    "model" => "gpt-4o",
    "key_prefix" => "gpt_trans",
  },
  output_schema: {
    "translated_text" => "string",
    "i18n_key" => "string",
    "locale" => 'en'
  },
)
