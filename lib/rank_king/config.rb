# frozen_string_literal: true

require "securerandom"

module RankKing
  # @rbs skip
  Config = Data.define(
    :database_url,
    :session_secret,
    :google_client_id,
    :google_client_secret,
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
        # A Google OAuth client, for connecting YouTube. Without one the
        # settings page says so and YouTube lists cannot be made.
        google_client_id: env["GOOGLE_CLIENT_ID"],
        google_client_secret: env["GOOGLE_CLIENT_SECRET"],
      )
    end
  end

  CONFIG = Config.from_env
end
