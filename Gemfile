source "https://rubygems.org"

gem "rails", "~> 8.0.2", ">= 8.0.2.1"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "haml"
gem "haml-rails"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "jbuilder"
gem "sidekiq"
gem "sidekiq-unique-jobs"
gem "redis", ">= 4.0"
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# HTTP client (often used with OpenAI)
gem "faraday"
gem "faraday-retry"
gem "openai"

# Required in config/boot.rb
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false

gem "connection_pool", "< 3.0"
gem "kaminari", "~> 1.2.1"
group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "faker"
  gem "web-console"
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "dotenv-rails"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end