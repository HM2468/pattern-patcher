# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.4.1
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

# ---- Runtime deps (final image needs these) ----
# - git: your app needs git CLI at runtime
# - libpq5: pg runtime
# - curl: healthchecks / misc
# - libjemalloc2: perf (Rails default template)
# - libvips: if you ever use image variants (Rails template)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      git \
      libjemalloc2 \
      libpq5 \
      libvips \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# ---- Build stage ----
FROM base AS build

# Build-time deps: compile native gems, build assets
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      nodejs \
      yarnpkg \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# JS deps (only if package.json exists)
# If you don't have package.json/yarn.lock, this step will be skipped.
COPY package.json yarn.lock ./
RUN if [ -f package.json ]; then yarnpkg install --frozen-lockfile; fi

# App code
COPY . .

# Bootsnap app precompile
RUN bundle exec bootsnap precompile app/ lib/

# Assets (Tailwind + Propshaft etc.)
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# ---- Final stage ----
FROM base AS final

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Security: non-root
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]