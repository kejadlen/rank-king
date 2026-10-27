# frozen_string_literal: true

require "pathname"

$LOAD_PATH.unshift(Pathname(__dir__).join("lib").to_s)

require_relative "lib/rank_king/web"

$stderr.puts RankKing::CONFIG

run RankKing::Web.freeze.app
