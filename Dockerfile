# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t atpking_blog .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name atpking_blog atpking_blog

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.2.1
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Configure apt and gem sources based on environment variable
ARG USE_CN_MIRRORS=true
RUN if [ "$USE_CN_MIRRORS" = "true" ]; then \
      cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
      sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
      sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
      gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/ && \
      bundle config mirror.https://rubygems.org https://gems.ruby-china.com; \
    fi

# Configure apt for better network resilience
RUN echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::http::Timeout "120";' > /etc/apt/apt.conf.d/99timeout && \
    echo 'Acquire::https::Timeout "120";' >> /etc/apt/apt.conf.d/99timeout

# Install base packages
RUN --mount=type=cache,target=/var/cache/apt \
    for i in $(seq 1 3); do \
      (apt-get update -qq && \
       apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 imagemagick && \
       exit 0) || if [ $i -eq 3 ]; then exit 1; fi; \
      echo "Retrying apt-get install... (attempt $i/3)"; \
      sleep 2; \
    done

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives


# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

RUN gem install tailwindcss-rails

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile --trace

# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p /rails/public/uploads && \
    chown -R rails:rails db log storage tmp public/uploads
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
