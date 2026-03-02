# frozen_string_literal: true

require "phlex"

require_relative "layout"

module RankKing
  module Views
    class Home < Phlex::HTML
      def initialize(lists:, csrf:)
        @lists = lists
        @csrf = csrf
      end

      def view_template
        render Layout.new do
          div(class: "home") do
            render_lists
            render_new_list_form
          end
        end
      end

      private

      def render_lists
        section(class: "section") do
          h2 { "Lists" }
          if @lists.empty?
            p(class: "empty") { "No lists yet." }
          else
            ul(class: "list-list") do
              @lists.each do |list|
                li do
                  a(href: "/lists/#{list.id}") { list.name }
                end
              end
            end
          end
        end
      end

      def render_new_list_form
        section(class: "section") do
          h2 { "New List" }
          form(method: "post", action: "/lists", class: "form") do
            input(type: "hidden", name: "_csrf", value: @csrf.call("/lists"))

            div(class: "field") do
              label(for: "name") { "Name" }
              input(type: "text", name: "name", id: "name", required: true)
            end

            div(class: "field") do
              label(for: "items") { "Items (one per line)" }
              textarea(name: "items", id: "items", rows: 6, required: true)
            end

            div(class: "field") do
              label(for: "axes") { "Axes (one per line)" }
              textarea(name: "axes", id: "axes", rows: 3, placeholder: "e.g. Taste\nValue\nConvenience")
            end

            button(type: "submit", class: "btn-primary") { "Create List" }
          end
        end
      end
    end
  end
end
