# frozen_string_literal: true

require "phlex"

require_relative "layout"

module RankKing
  module Views
    class Home < Phlex::HTML
      def initialize(lists:)
        @lists = lists
      end

      def view_template
        render Layout.new do
          render PageHeader.new(title: "Rank King") do
            a(href: "/settings", class: "icon-button", data_size: "lg", aria_label: "Settings",
              style: "--gl-icon: var(--rk-icon-settings)")
            a(href: "/lists/new", class: "btn", data_variant: "primary", data_size: "sm",
              style: "--gl-icon: var(--gl-icon-plus)") { "New list" }
          end

          section do
            h2(class: "type-label") { "Lists" }
            if @lists.empty?
              p { "No lists yet." }
            else
              ul(class: "card") do
                @lists.each do |list|
                  li { a(href: "/lists/#{list.id}") { list.name } }
                end
              end
            end
          end
        end
      end
    end
  end
end
