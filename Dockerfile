# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t sslguala2 .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name sslguala2 sslguala2

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Match .ruby-version. Build the official release while the 4.0.9 image is unavailable.
# https://www.ruby-lang.org/en/news/2026/10/23/regexp-fixes-for-gitlab-cves/
# ponytail: temporary source build; use the official slim image once its tag is published.
ARG TARGET_RUBY_VERSION=4.0.9
FROM docker.io/library/ruby:4.0.1-slim AS ruby-build
ARG TARGET_RUBY_VERSION
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential curl xz-utils libssl-dev libyaml-dev zlib1g-dev libgmp-dev libffi-dev libreadline-dev
# Preserve the official image's YJIT/ZJIT support and compiler hardening.
RUN curl -fsSL --retry 3 https://static.rust-lang.org/rustup/archive/1.28.2/x86_64-unknown-linux-gnu/rustup-init -o /tmp/rustup-init && \
    echo "20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c  /tmp/rustup-init" | sha256sum -c - && \
    chmod +x /tmp/rustup-init && \
    /tmp/rustup-init -y --no-modify-path --profile minimal --default-toolchain 1.91.1
RUN curl -fsSL --retry 3 "https://cache.ruby-lang.org/pub/ruby/4.0/ruby-${TARGET_RUBY_VERSION}.tar.xz" -o /tmp/ruby.tar.xz && \
    echo "a8057adb39f51ad6dc3106237504c93dd792bb515837b4fe7817ae21ed7e51f4  /tmp/ruby.tar.xz" | sha256sum -c - && \
    mkdir /tmp/ruby-source && tar -xJf /tmp/ruby.tar.xz -C /tmp/ruby-source --strip-components=1 && \
    cd /tmp/ruby-source && \
    PATH="/root/.cargo/bin:$PATH" LDFLAGS="-Wl,-z,relro -Wl,-z,now" ./configure --prefix=/usr/local --disable-install-doc --enable-shared --enable-yjit --enable-zjit && \
    PATH="/root/.cargo/bin:$PATH" make -j4 && \
    PATH="/root/.cargo/bin:$PATH" make install DESTDIR=/ruby-runtime

FROM docker.io/library/ruby:4.0.1-slim AS base
ARG TARGET_RUBY_VERSION
ENV RUBY_VERSION=${TARGET_RUBY_VERSION}
# Remove the old standard library/default gems before installing the verified release.
RUN rm -rf /usr/local/lib/ruby /usr/local/include/ruby-4.0.0
COPY --from=ruby-build /ruby-runtime/usr/local/ /usr/local/
RUN ldconfig && ruby -ropenssl -rpsych -rzlib -rfiddle -e 'abort "Ruby version mismatch" unless RUBY_VERSION == ENV.fetch("RUBY_VERSION")'

WORKDIR /rails
RUN apt-get update -qq && apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 rsync openssh-client && rm -rf /var/lib/apt/lists/*
ENV RAILS_ENV="production" BUNDLE_DEPLOYMENT="1" BUNDLE_PATH="/usr/local/bundle" BUNDLE_WITHOUT="development:test" LD_PRELOAD="libjemalloc.so.2" MALLOC_CONF="dirty_decay_ms:1000,narenas:2,background_thread:true"

FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential git pkg-config libyaml-dev && rm -rf /var/lib/apt/lists/*
COPY .ruby-version Gemfile Gemfile.lock ./
RUN gem install bundler -v 4.0.23 --no-document && bundle install && rm -rf /usr/local/bundle/ruby/*/cache
COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base
ARG REVISION=unknown
ENV REVISION=${REVISION}
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
RUN groupadd --system --gid 1000 rails && useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && mkdir -p public/uploads && chown -R rails:rails db log storage tmp public/uploads
USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
