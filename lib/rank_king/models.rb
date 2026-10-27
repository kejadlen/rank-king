# frozen_string_literal: true

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

    plugin :serialization, :json, :source_config

    def source = Sources.fetch(source_kind).new(source_config)
  end

  # @rbs skip
  class Item < Sequel::Model(DB[:items])
    plugin :serialization, :json, :metadata

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
