# frozen_string_literal: true

require_relative "models"

module RankKing
  # Sample lists for the dev server and the Fly apps, whose database
  # starts empty (DATABASE_URL defaults to :memory:). Only demo.ru seeds,
  # and only a user with no lists, so restarting against a database file
  # leaves what is already in it alone.
  module Seed
    # Each list's items and axes, and a few results already recorded on
    # it as [axis, winner, loser], so its ratings are not all equal.
    LISTS = {
      "Pizza toppings" => {
        items: ["Pepperoni", "Mushroom", "Pineapple", "Sausage", "Olives", "Basil"],
        axes: ["Taste", "Value"],
        results: [
          ["Taste", "Pepperoni", "Pineapple"],
          ["Taste", "Basil", "Olives"],
          ["Taste", "Sausage", "Mushroom"],
          ["Value", "Mushroom", "Sausage"],
          ["Value", "Olives", "Pepperoni"],
        ],
      },
      "Board games" => {
        items: ["Catan", "Ticket to Ride", "Azul", "Wingspan", "Codenames", "Carcassonne"],
        axes: ["Fun", "Replayability", "Ease of teaching"],
        results: [],
      },
      "Weekend hikes" => {
        items: ["Mission Peak", "Mount Tam", "Point Reyes", "Muir Woods"],
        axes: [],
        results: [],
      },
    } #: Hash[String, { items: Array[String], axes: Array[String], results: Array[[String, String, String]] }]

    #: (String login) -> void
    def self.call(login)
      user = User.find_or_create(login: login)
      return if List.where(user_id: user.id).first

      DB.transaction do
        LISTS.each do |name, list|
          create_list(user, name, **list)
        end
      end
    end

    #: (User user, String name, items: Array[String], axes: Array[String], results: Array[[String, String, String]]) -> void
    def self.create_list(user, name, items:, axes:, results:)
      l = List.create(name: name, user_id: user.id)
      items_by_name = items.to_h do |n|
        [n, Item.create(list_id: l.id, name: n)] #: [String, Item]
      end
      axes_by_name = axes.to_h do |n|
        [n, Axis.create(list_id: l.id, name: n)] #: [String, Axis]
      end
      results.each do |axis, winner, loser|
        Result.create(
          axis_id: axes_by_name.fetch(axis).id,
          winner_id: items_by_name.fetch(winner).id,
          loser_id: items_by_name.fetch(loser).id,
        )
      end
    end
  end
end
