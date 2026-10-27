# frozen_string_literal: true

require "json"

require_relative "db"
require_relative "sources"

Sequel::Model.plugin :timestamps, update_on_create: true

module RankKing
  # Signed in sig/rank_king/models.rbs: the superclass is not a constant.
  # @rbs skip
  class List < Sequel::Model(DB[:lists])
    # Archived items are hidden everywhere for now.
    one_to_many :items, class: "RankKing::Item", conditions: { archived_at: nil }
    one_to_many :axes, class: "RankKing::Axis"

    def source_config = JSON.parse(super)
    def source_config=(value)
      super(JSON.generate(value))
    end

    def source = Sources.fetch(source_kind).new(source_config)
  end

  # @rbs skip
  class Item < Sequel::Model(DB[:items])
    # JSON by hand rather than Sequel's serialization plugin, which passes
    # json 3.1 an option it no longer takes.
    def metadata = JSON.parse(super)
    def metadata=(value)
      super(JSON.generate(value))
    end

    many_to_one :list, class: "RankKing::List"
  end

  # @rbs skip
  class Axis < Sequel::Model(DB[:axes])
    one_to_many :results, class: "RankKing::Result"
  end

  # @rbs skip
  class Result < Sequel::Model(DB[:results])
    many_to_one :axis, class: "RankKing::Axis"
    many_to_one :winner, class: "RankKing::Item"
    many_to_one :loser, class: "RankKing::Item"
  end
end
