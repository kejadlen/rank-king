# frozen_string_literal: true

source "https://rubygems.org"

gem "phlex"
gem "puma"
gem "rackup"
gem "roda"
gem "sequel"
gem "sqlite3"

group :development do
  gem "minitest"
  gem "rack-test"
  gem "rake"
  # Pinned to a prerelease: released Steep parses Ruby as 3.3, where `it`
  # is a method call rather than the block parameter. 2.1.0.dev.1 is the
  # first release parsing 3.4.
  gem "steep", "2.1.0.dev.1"
end
