# frozen_string_literal: true

require_relative "proxy_auth"

module RankKing
  # Rack middleware that writes a fixed login to Remote-User, the way the
  # proxy in front of a deployment does. Only demo.ru uses it (the dev server
  # and the Fly apps); config.ru must not, or every anonymous caller would be
  # that user. A request that already carries the header keeps its own, so
  # `curl -H` can still ask as someone else.
  class StubLogin
    LOGIN = "alpha@example.com"

    def initialize(app)
      @app = app
    end

    def call(env)
      env[ProxyAuth::ENV_KEY] ||= LOGIN
      @app.call(env)
    end
  end
end
