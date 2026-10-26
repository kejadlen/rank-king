# frozen_string_literal: true

require "securerandom"

module RankKing
  # @rbs skip
  Config = Data.define(
    :database_url,
    :session_secret,
  )

  class Config
    #: () -> String
    def to_s
      "Config(database=#{database_url})"
    end

    #: (?Hash[String, String] env) -> Config
    def self.from_env(env = ENV)
      new(
        database_url: env.fetch("DATABASE_URL", ":memory:"),
        session_secret: env.fetch("SESSION_SECRET") { SecureRandom.hex(64) },
      )
    end
  end

  CONFIG = Config.from_env
end
