# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require_relative "lib/rank_king/web"

$stderr.puts RankKing::CONFIG

run RankKing::Web.freeze.app
