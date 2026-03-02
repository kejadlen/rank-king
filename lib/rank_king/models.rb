# frozen_string_literal: true

require_relative "db"

Sequel::Model.plugin :timestamps, update_on_create: true

module RankKing
  class List < Sequel::Model(DB[:lists])
    one_to_many :items, class: "RankKing::Item"
    one_to_many :axes, class: "RankKing::Axis"
  end

  class Item < Sequel::Model(DB[:items])
    many_to_one :list, class: "RankKing::List"
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
