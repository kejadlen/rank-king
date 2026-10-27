# frozen_string_literal: true

module RankKing
  # Who is asking: the login on Remote-User, which the proxy in front of this
  # app writes (Tailscale identity, through Caddy). It is trustworthy only
  # behind such a proxy, so the app must not listen anywhere but localhost.
  # StubLogin stands in for the proxy where there is none (demo.ru).
  module ProxyAuth
    HEADER = "Remote-User" #: String
    ENV_KEY = "HTTP_#{HEADER.upcase.tr("-", "_")}" #: String

    class MissingLogin < StandardError
    end

    #: (Hash[String, untyped] env) -> String
    def self.login(env)
      login = env[ENV_KEY].to_s.dup.force_encoding(Encoding::UTF_8)
      raise MissingLogin, "the #{HEADER} header is not valid UTF-8" unless login.valid_encoding?

      login = login.strip
      raise MissingLogin, "no login on the #{HEADER} header" if login.empty?

      login
    end
  end
end
