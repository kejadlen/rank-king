# Ramekin image for rank-king (Ruby 4 webapp).
#
# FROM ramekin-agent to keep the pi harness. Switch to ramekin-base for a
# leaner image without the agent.
#
# Ruby 4 is not in trixie's apt (it ships 3.x), so Ruby is built from source.
# Adjust RUBY_VERSION if the released patch differs from the default.

FROM ramekin-agent

ARG RUBY_VERSION=4.0.0
ENV RUBY_VERSION=${RUBY_VERSION}

# Toolchain and headers for building Ruby and for any native gem that lacks a
# precompiled binary (sqlite3 and puma usually ship one, but keep these).
# locales so Ruby reads source as UTF-8 rather than US-ASCII.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential autoconf bison \
      libssl-dev libyaml-dev libreadline-dev zlib1g-dev libffi-dev \
      ca-certificates wget locales \
 && rm -rf /var/lib/apt/lists/*

# A locale named in the environment but never generated is as good as absent
# — Ruby falls back to US-ASCII — so generate it and set it as the default.
RUN sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN wget -q "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz" \
 && tar -xzf "ruby-${RUBY_VERSION}.tar.gz" \
 && cd "ruby-${RUBY_VERSION}" \
 && ./configure --disable-install-doc \
 && make -j"$(nproc)" \
 && make install \
 && cd / && rm -rf "ruby-${RUBY_VERSION}" "ruby-${RUBY_VERSION}.tar.gz"

# Match the bundler pinned in Gemfile.lock (BUNDLED WITH).
RUN gem install bundler -v 4.0.3

# Install project gems at build time so bundle/rake/puma are ready each session.
# Build context is expected to be the project root.
COPY Gemfile Gemfile.lock /tmp/bundle/
RUN cd /tmp/bundle \
 && bundle install --jobs 4 \
 && rm -rf /tmp/bundle
