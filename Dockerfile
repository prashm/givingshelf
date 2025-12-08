# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t bookshare .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name bookshare bookshare

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.4
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# System dependencies (Postgres, Redis, Image Processing)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
    libvips \
    libpq-dev \
    redis-tools \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Rails production defaults
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

# -------------------
# BUILD STAGE
# -------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libyaml-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Ruby gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle \
    "${BUNDLE_PATH}"/ruby/*/cache \
    "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy app code
COPY . .

# Install JS deps + build React/Tailwind
RUN npm install && npm run build

# Precompile bootsnap
RUN bundle exec bootsnap precompile app/ lib/

# Precompile rails assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# -------------------
# FINAL RUNTIME IMAGE
# -------------------
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Rails logging to stdout
ENV RAILS_LOG_TO_STDOUT=true

# Default Rails port (Nginx will proxy)
EXPOSE 3000

# Proper Rails server start (NO thruster)
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
