# frozen_string_literal: true

require "phlex"

module RankKing
  module Views
    module Sources
      # The Text source's sync dialog: every item's name, editable in place,
      # and a box for new ones. It fills a <dialog> as Gloss lays one out:
      # header, body, footer, so the form is the body and the footer's
      # Save reaches it by id.
      class Text < Phlex::HTML
        def initialize(list:, csrf:)
          @list = list
          @csrf = csrf
        end

        def view_template
          action = "/lists/#{@list.id}/sync"

          header { "Edit items" }
          form(id: "sync-form", method: "post", action:) do
            input(type: "hidden", name: "_csrf", value: @csrf.call(action))
            p { "Clear a name to remove that item." }
            @list.items_dataset.order(:id).each do |item|
              input(type: "text", name: "items[#{item.id}]", value: item.name, aria_label: "Item name")
            end
            label(class: "field") do
              plain "Add items"
              textarea(name: "new_items", rows: 3)
              small { "One per line." }
            end
          end
          footer do
            button(type: "button", commandfor: "sync-dialog", command: "close") { "Cancel" }
            button(type: "submit", form: "sync-form", data_variant: "primary") { "Save" }
          end
        end
      end
    end
  end
end
