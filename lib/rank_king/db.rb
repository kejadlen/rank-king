# frozen_string_literal: true

require "sequel"

require_relative "config"

module RankKing
  DB = Sequel.sqlite(CONFIG.database_url)
  Sequel.extension :migration
  # `__dir__` is nil only for code with no file behind it, which a
  # required library is not, and the assertion says so to Steep.
  MIGRATIONS = File.expand_path(
    "../../db/migrate",
    __dir__, #: String
  )
  Sequel::Migrator.run(DB, MIGRATIONS)
end
