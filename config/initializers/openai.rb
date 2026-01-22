# config/initializers/openai.rb
return unless defined?(OpenAI)

if OpenAI.respond_to?(:configure)
  OpenAI.configure do |config|
    config.access_token = ENV["OPENAI_ACCESS_TOKEN"]
  end
end