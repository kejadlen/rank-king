# frozen_string_literal: true

require "phlex"

require_relative "../layout"
require_relative "../axis_tags"

module RankKing
  module Views
    module ListViews
      class New < Phlex::HTML
        def initialize(sources:, csrf:)
          @sources = sources
          @csrf = csrf
        end

        def view_template
          render Layout.new(title: "New list — Rank King") do
            render PageHeader.new(title: "New list", back: "/", back_label: "Lists")

            form(method: "post", action: "/lists") do
              input(type: "hidden", name: "_csrf", value: @csrf.call("/lists"))

              label(class: "field") do
                plain "Name"
                input(type: "text", name: "name", required: true, autofocus: true)
              end

              label(class: "field") do
                plain "Source"
                select(name: "source") do
                  @sources.each { |value, name| option(value: value) { name } }
                end
                small { "A list keeps its source." }
              end

              # The chosen source's own fields. Each source gets one of these.
              fieldset(data_source: "Text") do
                label(class: "field") do
                  plain "Items"
                  textarea(name: "items", rows: 6, required: true)
                  small { "One per line, at least two." }
                end
              end

              render AxisTags.new

              footer do
                button(type: "submit", data_variant: "primary") { "Create list" }
              end
            end
          end
        end
      end
    end
  end
end
