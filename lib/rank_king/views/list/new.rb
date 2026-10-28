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
                  @sources.each do |kind, title, _fields|
                    option(value: kind) { title }
                  end
                end
                small { "A list keeps its source." }
              end

              # Each source's own fields. Only the chosen source's are
              # enabled, so only they are checked and posted; app.js
              # switches them when the dropdown changes.
              @sources.each_with_index do |(kind, _title, fields), index|
                fieldset(data_source: kind, disabled: index > 0, hidden: index > 0) { render fields }
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
