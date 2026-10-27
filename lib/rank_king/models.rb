# frozen_string_literal: true

require_relative "db"
require_relative "sources"

Sequel::Model.plugin :timestamps, update_on_create: true

module RankKing
  # Signed in sig/rank_king/models.rbs: the superclass is not a constant.
  # @rbs skip
  class User < Sequel::Model(DB[:users])
    one_to_many :lists, class: "RankKing::List"
  end

  # @rbs skip
  class List < Sequel::Model(DB[:lists])
    many_to_one :user, class: "RankKing::User"
    # Archived items are hidden everywhere for now.
    one_to_many :items, class: "RankKing::Item", conditions: { archived_at: nil }
    one_to_many :axes, class: "RankKing::Axis"

    def source = Sources.fetch(source_kind).for(self)

    # Archived items too, which the items association leaves out.
    def before_destroy
      Result.where(axis_id: axes_dataset.select(:id)).delete
      axes_dataset.delete
      Item.where(list_id: id).delete
      super
    end
  end

  # @rbs skip
  class Item < Sequel::Model(DB[:items])
    many_to_one :list, class: "RankKing::List"
  end

  # @rbs skip
  class Axis < Sequel::Model(DB[:axes])
    many_to_one :list, class: "RankKing::List"
    one_to_many :results, class: "RankKing::Result"

    # The list's items in order on this axis, then the ones with no
    # results on it yet. Ordered by win count until OpenSkill is wired in.
    def ranking
      wins = Hash.new(0)
      compared = Set.new
      results.each do |result|
        wins[result.winner_id] += 1
        compared << result.winner_id << result.loser_id
      end

      ranked, unranked = list.items.partition { |item| compared.include?(item.id) }
      [ranked.sort_by { |item| [-wins[item.id], item.id] }, unranked]
    end

    def before_destroy
      results_dataset.delete
      super
    end
  end

  # @rbs skip
  class Result < Sequel::Model(DB[:results])
    many_to_one :axis, class: "RankKing::Axis"
    many_to_one :winner, class: "RankKing::Item"
    many_to_one :loser, class: "RankKing::Item"
  end
end
