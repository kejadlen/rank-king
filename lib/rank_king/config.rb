# frozen_string_literal: true

require "securerandom"

module RankKing
  Config = Data.define(
    :database_url,
    :session_secret,
    :auth,
    :local_user,
  )

  class Config
    def to_s
      "Config(database=#{database_url}, auth=#{auth})"
    end

    def self.from_env(env = ENV)
      auth = env.fetch("AUTH", "local")
      raise ArgumentError, "unknown AUTH: #{auth}" unless %w[local tailscale].include?(auth)

      new(
        database_url: env.fetch("DATABASE_URL", ":memory:"),
        session_secret: env.fetch("SESSION_SECRET") { SecureRandom.hex(64) },
        auth:,
        local_user: env.fetch("LOCAL_USER", "local"),
      )
    end
  end

  CONFIG = Config.from_env
end
