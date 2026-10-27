# frozen_string_literal: true

require "pathname"
require "sequel"

require_relative "config"

module RankKing
  DB = Sequel.sqlite(CONFIG.database_url)
  Sequel.extension :migration
  # `__dir__` is nil only for code with no file behind it, which a
  # required library is not, and the assertion says so to Steep.
  MIGRATIONS = Pathname(
    __dir__, #: String
  ).join("../../db/migrate").expand_path
  Sequel::Migrator.run(DB, MIGRATIONS.to_s)
end
