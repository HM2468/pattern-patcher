# syntax=docker/dockerfile:1
# check=error=true

FROM ruby:3.4.1-slim-bullseye

WORKDIR /rails

# ---- Base deps for local tool usage (build + runtime) ----
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      git \
      libjemalloc2 \
      libpq5 \
      libvips \
      build-essential \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      nodejs \
      yarnpkg \
      postgresql-client \
      redis-tools \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Bundler defaults (dev-friendly)
ENV BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_JOBS="4" \
    BUNDLE_RETRY="3"

# Keep gems cache reusable across containers
VOLUME ["/usr/local/bundle"]

# ---- Install Ruby gems (cached by Gemfile/Gemfile.lock) ----
COPY Gemfile Gemfile.lock ./
RUN bundle install

# ---- Install JS deps (cached by package.json/yarn.lock) ----
COPY package.json yarn.lock ./
RUN if [ -f package.json ]; then yarnpkg install --frozen-lockfile; fi

# NOTE:
# - 不 COPY . .
# - 不写 CMD / ENTRYPOINT
# - 代码由 docker-compose 通过 bind mount 挂载进来