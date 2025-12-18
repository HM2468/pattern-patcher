source "https://rubygems.org"

# ------------------------------------------------------------
# Core framework
# ------------------------------------------------------------

# Use Rails 8
gem "rails", "~> 8.0.2", ">= 8.0.2.1"

# Modern asset pipeline for Rails
# https://github.com/rails/propshaft
gem "propshaft"

# SQLite database for Active Record
gem "sqlite3", ">= 2.1"

# Puma web server
# https://github.com/puma/puma
gem "puma", ">= 5.0"
gem "haml"
gem "haml-rails"
# ------------------------------------------------------------
# Frontend / Hotwire
# ------------------------------------------------------------

# JavaScript with ESM import maps
# https://github.com/rails/importmap-rails
gem "importmap-rails"

# Hotwire: Turbo (SPA-like navigation)
# https://turbo.hotwired.dev
gem "turbo-rails"

# Hotwire: Stimulus (modest JS framework)
# https://stimulus.hotwired.dev
gem "stimulus-rails"

# Tailwind CSS integration
# https://github.com/rails/tailwindcss-rails
gem "tailwindcss-rails"

# Build JSON APIs
# https://github.com/rails/jbuilder
gem "jbuilder"

# ------------------------------------------------------------
# Background jobs / Async processing
# ------------------------------------------------------------

# Background job processing
# https://github.com/sidekiq/sidekiq
gem "sidekiq"

# Prevent duplicate jobs (important for scan / process tasks)
# https://github.com/mhenrixon/sidekiq-unique-jobs
gem "sidekiq-unique-jobs"

# Redis client (Sidekiq dependency)
gem "redis", ">= 4.0"

# ------------------------------------------------------------
# Caching / Queue / Cable (Rails 8 solid adapters)
# ------------------------------------------------------------

# Database-backed cache
gem "solid_cache"

# Database-backed Active Job adapter (optional, Sidekiq is primary)
gem "solid_queue"

# Database-backed Action Cable
gem "solid_cable"

# ------------------------------------------------------------
# LLM / HTTP (to be enabled when needed)
# ------------------------------------------------------------

# OpenAI official Ruby SDK (enable when wiring LLM features)
gem "openai"

# HTTP client (often used with OpenAI)
gem "faraday"
gem "faraday-retry"

# ------------------------------------------------------------
# Performance / Deployment
# ------------------------------------------------------------

# Boot time optimization
# Required in config/boot.rb
gem "bootsnap", require: false

# Deploy anywhere with Docker
# https://kamal-deploy.org
gem "kamal", require: false

# HTTP asset caching / compression for Puma
# https://github.com/basecamp/thruster/
gem "thruster", require: false

# Rails 8 RedisCacheStore is not compatible with connection_pool 3.x (keyword-only initializer)
gem "connection_pool", "< 3.0"

group :development, :test do
  # Debugger
  # https://guides.rubyonrails.org/debugging_rails_applications.html
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Static security analysis
  # https://brakemanscanner.org/
  gem "brakeman", require: false

  # Rails Omakase RuboCop rules
  # https://github.com/rails/rubocop-rails-omakase/
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Console on exception pages
  # https://github.com/rails/web-console
  gem "web-console"

  # Linting / code style
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "dotenv-rails"
end

group :test do
  # System testing
  # https://guides.rubyonrails.org/testing.html#system-testing
  gem "capybara"
  gem "selenium-webdriver"
end