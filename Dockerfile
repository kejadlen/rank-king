FROM ruby:4.0-slim AS build

RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle config set without development && bundle install

COPY . .

FROM ruby:4.0-slim

# The image's own tag, and the release's name (see ci.yml).
ARG VERSION
ENV VERSION=${VERSION}
# rackup defaults to development, which wraps the app in Rack::Lint and
# ShowExceptions.
ENV RACK_ENV=production

WORKDIR /app

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

EXPOSE 9292

CMD ["rackup", "-o", "0.0.0.0"]
