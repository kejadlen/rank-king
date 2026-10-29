# frozen_string_literal: true

require "open3"
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
        # A Google OAuth client, for connecting YouTube. The secret comes
        # from a command, so it can live in a file or a password manager
        # rather than the environment.
        google_client_id: env.fetch("GOOGLE_CLIENT_ID"),
        google_client_secret: secret_from(env.fetch("GOOGLE_CLIENT_SECRET_COMMAND")),
      )
    end

    # Runs a shell command, such as `op read op://…` or `cat path`, and
    # returns what it prints.
    #: (String command) -> String
    def self.secret_from(command)
      output, status = Open3.capture2(command)
      raise "#{command} exited with #{status.exitstatus}" unless status.success?

      output.strip
    end
  end

  CONFIG = Config.from_env
end
