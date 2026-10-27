# frozen_string_literal: true

require "phlex"

require_relative "../layout"

module RankKing
  module Views
    module ListViews
      class Compare < Phlex::HTML
        RECENT = 5

        def initialize(list:, axis:, csrf:)
          @list = list
          @axis = axis
          @csrf = csrf
        end

        def view_template
          render Layout.new(title: "#{@axis.name} · #{@list.name} — Rank King") do
            render PageHeader.new(title: @list.name, back: "/lists/#{@list.id}?axis=#{@axis.id}", back_label: @list.name)

            section do
              h2(class: "type-label") { "Which wins on #{@axis.name}?" }
              render_matchup
            end

            render_recent
          end
        end

        private

        def render_matchup
          first, second = @list.items.sample(2)

          div(data_matchup: true) do
            render_choice(first, second)
            render_choice(second, first)
          end

          a(href: "/lists/#{@list.id}/axes/#{@axis.id}/compare", class: "btn", data_variant: "ghost") { "Skip" }
        end

        def render_choice(winner, loser)
          action = "/lists/#{@list.id}/results"
          form(method: "post", action: action) do
            input(type: "hidden", name: "_csrf", value: @csrf.call(action))
            input(type: "hidden", name: "axis_id", value: @axis.id)
            input(type: "hidden", name: "winner_id", value: winner.id)
            input(type: "hidden", name: "loser_id", value: loser.id)
            button(type: "submit") { winner.name }
          end
        end

        def render_recent
          results = @axis.results_dataset.reverse(:id).limit(RECENT).all
          return if results.empty?

          section do
            h2(class: "type-label") { "Recent" }
            ul(class: "card") do
              results.each do |result|
                li do
                  span do
                    strong { result.winner.name }
                    plain " over #{result.loser.name}"
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
