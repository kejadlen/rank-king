# frozen_string_literal: true

require_relative "db"
require_relative "sources"

Sequel::Model.plugin :timestamps, update_on_create: true

module RankKing
  class List < Sequel::Model(DB[:lists])
    # Archived items are hidden everywhere for now.
    one_to_many :items, class: "RankKing::Item", conditions: { archived_at: nil }
    one_to_many :axes, class: "RankKing::Axis"
    one_to_many :sources, class: "RankKing::Source"
  end

  class Item < Sequel::Model(DB[:items])
    plugin :serialization, :json, :metadata

    many_to_one :list, class: "RankKing::List"
    many_to_one :source, class: "RankKing::Source"
  end

  class Source < Sequel::Model(DB[:sources])
    plugin :serialization, :json, :config

    many_to_one :list, class: "RankKing::List"
    one_to_many :items, class: "RankKing::Item"

    def plugin = Sources.fetch(kind).new(config)
  end

  class Axis < Sequel::Model(DB[:axes])
    one_to_many :results, class: "RankKing::Result"
  end

  class Result < Sequel::Model(DB[:results])
    many_to_one :axis, class: "RankKing::Axis"
    many_to_one :winner, class: "RankKing::Item"
    many_to_one :loser, class: "RankKing::Item"
  end
end
