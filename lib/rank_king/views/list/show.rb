# frozen_string_literal: true

require "phlex"

require_relative "../layout"

module RankKing
  module Views
    module ListViews
      class Show < Phlex::HTML
        def initialize(list:, csrf:)
          @list = list
          @csrf = csrf
        end

        def view_template
          render Layout.new(title: "#{@list.name} — Rank King") do
            div(class: "list-show") do
              h1 { @list.name }
              render_items
              render_source
              render_axes
              render_matchup
              render_ratings
            end
          end
        end

        private

        def render_items
          section(class: "section") do
            h2 { "Items" }
            ul(class: "item-list") do
              @list.items.each do |item|
                li { item.name }
              end
            end
          end
        end

        def render_source
          source = @list.source
          action = "/lists/#{@list.id}/sync"

          section(class: "section") do
            h2 { "Source" }
            form(method: "post", action:, class: "form") do
              input(type: "hidden", name: "_csrf", value: @csrf.call(action))

              if source.class.push?
                div(class: "field") do
                  label(for: "snapshot") { "Items (one per line)" }
                  textarea(name: "snapshot", id: "snapshot", rows: 6) do
                    @list.items_dataset.order(:id).map(:name).join("\n")
                  end
                end
              end

              button(type: "submit", class: "btn-primary") { "Sync" }
            end
          end
        end

        def render_axes
          section(class: "section") do
            h2 { "Axes" }
            if @list.axes.empty?
              p(class: "empty") { "No axes defined." }
            else
              ul(class: "axis-list") do
                @list.axes.each do |axis|
                  li { axis.name }
                end
              end
            end
          end
        end

        def render_matchup
          return if @list.axes.empty? || @list.items.size < 2

          items = @list.items.to_a
          pair = items.sample(2)
          axis = @list.axes.to_a.sample

          section(class: "section") do
            h2 { "Matchup" }
            p(class: "matchup-axis") { "On: #{axis.name}" }
            div(class: "matchup") do
              form(method: "post", action: "/lists/#{@list.id}/results", class: "matchup-choice") do
                input(type: "hidden", name: "_csrf", value: @csrf.call("/lists/#{@list.id}/results"))
                input(type: "hidden", name: "axis_id", value: axis.id)
                input(type: "hidden", name: "winner_id", value: pair[0].id)
                input(type: "hidden", name: "loser_id", value: pair[1].id)
                button(type: "submit", class: "btn-choice") { pair[0].name }
              end

              span(class: "matchup-vs") { "vs" }

              form(method: "post", action: "/lists/#{@list.id}/results", class: "matchup-choice") do
                input(type: "hidden", name: "_csrf", value: @csrf.call("/lists/#{@list.id}/results"))
                input(type: "hidden", name: "axis_id", value: axis.id)
                input(type: "hidden", name: "winner_id", value: pair[1].id)
                input(type: "hidden", name: "loser_id", value: pair[0].id)
                button(type: "submit", class: "btn-choice") { pair[1].name }
              end
            end
          end
        end

        def render_ratings
          return if @list.axes.empty?

          section(class: "section") do
            h2 { "Ratings" }
            @list.axes.each do |axis|
              render_axis_ratings(axis)
            end
          end
        end

        def render_axis_ratings(axis)
          results = axis.results
          return if results.empty?

          ratings = compute_ratings(axis)

          div(class: "axis-ratings") do
            h3 { axis.name }
            ol(class: "rating-list") do
              ratings.each do |item, rating|
                li { "#{item.name} — #{format("%.0f", rating)}" }
              end
            end
          end
        end

        def compute_ratings(axis)
          # Placeholder: simple win count until openskill is added
          wins = Hash.new(0)
          axis.results.each { |r| wins[r.winner_id] += 1 }

          items_by_id = @list.items.to_h { |i| [i.id, i] }
          wins
            .sort_by { |_, count| -count }
            .map { |id, count| [items_by_id[id], count] }
            .select { |item, _| item }
        end
      end
    end
  end
end
