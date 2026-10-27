# frozen_string_literal: true

require "phlex"

module RankKing
  module Views
    module Sources
      # The Text source's sync dialog: every item's name, editable in place,
      # and a box for new ones.
      class Text < Phlex::HTML
        def initialize(list:, csrf:)
          @list = list
          @csrf = csrf
        end

        def view_template
          action = "/lists/#{@list.id}/sync"
          form(method: "post", action:, class: "form") do
            input(type: "hidden", name: "_csrf", value: @csrf.call(action))
            h2 { "Edit items" }
            p(class: "empty") { "Clear a name to remove that item." }
            @list.items_dataset.order(:id).each do |item|
              input(type: "text", name: "items[#{item.id}]", value: item.name, aria_label: "Item name")
            end
            div(class: "field") do
              label(for: "new-items") { "Add items, one per line" }
              textarea(name: "new_items", id: "new-items", rows: 3)
            end
            div(class: "dialog-actions") do
              button(type: "button", class: "btn-link", commandfor: "sync-dialog", command: "close") { "Cancel" }
              button(type: "submit", class: "btn-primary") { "Save" }
            end
          end
        end
      end
    end
  end
end
