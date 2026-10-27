# frozen_string_literal: true

# The demo entrypoint: config.ru plus a login written the way the proxy would
# write it. The dev server and the Fly apps serve from here; a deployment
# behind the proxy runs config.ru alone.

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require "rank_king/stub_login"

use RankKing::StubLogin
run Rack::Builder.parse_file(File.expand_path("config.ru", __dir__))
