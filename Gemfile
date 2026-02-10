source "https://rubygems.org"

gem "rails", "~> 8.1", ">= 8.1.2"
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
gem "commonmarker"

# HTTP client (often used with OpenAI)
gem "faraday"
gem "faraday-retry"
gem "openai"

# Required in config/boot.rb
gem "bootsnap", "~> 1.21.0", require: false
gem "kamal", require: false
gem "thruster", require: false

gem "connection_pool", "< 3.0"
gem "kaminari", "~> 1.2.1"


group :development, :test do
  gem "brakeman", "~> 7.1.2", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "faker"
  gem "web-console"
  gem "rubocop", require: false
  gem "rubocop-rails", "~> 2.34.3", require: false
  gem "rubocop-rspec", require: false
  gem "dotenv-rails"
  gem "rails-erd", "~> 1.7"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end