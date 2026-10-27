# frozen_string_literal: true

require "phlex"

require_relative "../layout"
require_relative "../axis_tags"

module RankKing
  module Views
    module ListViews
      # A future setting is a new section of this form, not a new screen.
      class Settings < Phlex::HTML
        def initialize(list:, source:, csrf:)
          @list = list
          @source = source
          @csrf = csrf
        end

        def view_template
          settings = "/lists/#{@list.id}/settings"
          delete = "/lists/#{@list.id}/delete"

          render Layout.new(title: "Settings · #{@list.name} — Rank King") do
            render PageHeader.new(title: "Settings", back: "/lists/#{@list.id}", back_label: @list.name)

            form(id: "settings", method: "post", action: settings) do
              input(type: "hidden", name: "_csrf", value: @csrf.call(settings))

              label(class: "field") do
                plain "Name"
                input(type: "text", name: "name", value: @list.name, required: true)
              end

              # A list keeps the source it was made from, so this is a
              # fact about the list, not a control.
              div(class: "field") do
                plain "Source"
                p { @source }
              end

              render AxisTags.new(axes: @list.axes, hint: "Removing an axis deletes its results.")
            end

            form(method: "post", action: delete, data_confirm: "Delete #{@list.name} and all its results?") do
              input(type: "hidden", name: "_csrf", value: @csrf.call(delete))
              footer do
                button(type: "submit", data_variant: "danger", data_size: "sm") { "Delete list" }
                button(type: "submit", form: "settings", data_variant: "primary") { "Save" }
              end
            end
          end
        end
      end
    end
  end
end
