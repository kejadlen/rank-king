# frozen_string_literal: true

require "securerandom"

module RankKing
  Config = Data.define(
    :database_url,
    :session_secret,
  )

  class Config
    def to_s
      "Config(database=#{database_url})"
    end

    def self.from_env(env = ENV)
      new(
        database_url: env.fetch("DATABASE_URL", ":memory:"),
        session_secret: env.fetch("SESSION_SECRET") { SecureRandom.hex(64) },
      )
    end
  end

  CONFIG = Config.from_env
end
