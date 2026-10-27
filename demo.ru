# frozen_string_literal: true

# The demo entrypoint: config.ru plus a login written the way the proxy would
# write it. The dev server and the Fly apps serve from here; a deployment
# behind the proxy runs config.ru alone.

require "pathname"

$LOAD_PATH.unshift(Pathname(__dir__).join("lib").to_s)

require "rank_king/stub_login"

use RankKing::StubLogin
run Rack::Builder.parse_file(Pathname(__dir__).join("config.ru").to_s)
