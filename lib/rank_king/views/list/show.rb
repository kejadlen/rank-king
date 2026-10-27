# frozen_string_literal: true

require "phlex"

require_relative "../layout"

module RankKing
  module Views
    module ListViews
      class Show < Phlex::HTML
        def initialize(list:, csrf:, axis: nil)
          @list = list
          @csrf = csrf
          @axes = list.axes
          @selected = axis || @axes.first
        end

        def view_template
          render Layout.new(title: "#{@list.name} — Rank King") do
            render PageHeader.new(title: @list.name, back: "/", back_label: "Lists", size: "type-h2") do
              render_menu
            end

            if @axes.empty?
              render_items
            else
              render_axes
            end
          end
        end

        private

        # Every list action lives here, so a new one is a new entry
        # rather than a new button on the screen. The source decides what
        # syncing looks like: its entry opens a dialog holding its own form.
        def render_menu
          source = @list.source

          button(class: "icon-button", data_size: "lg", popovertarget: "list-actions", aria_label: "List actions",
                 style: "--gl-icon: var(--rk-icon-more)")
          nav(id: "list-actions", popover: true, aria_label: "List actions") do
            ul(class: "card") do
              li { button(type: "button", commandfor: "sync-dialog", command: "show-modal") { source.label } }
              li { a(href: "/lists/#{@list.id}/settings") { "Settings" } }
            end
          end
          dialog(id: "sync-dialog") { render source.form(csrf: @csrf) }
        end

        # Nothing to compare on yet. The "+ Axis" slot stands where the
        # axis tabs will, and Enter makes the first one.
        def render_items
          action = "/lists/#{@list.id}/axes"
          form(method: "post", action: action, data_first_axis: true) do
            input(type: "hidden", name: "_csrf", value: @csrf.call(action))
            span(class: "tag", data_dashed: true) do
              input(type: "text", name: "name", required: true, placeholder: "+ Axis", aria_label: "New axis")
            end
          end

          ul(class: "card") do
            @list.items.each { |item| li { item.name } }
          end
        end

        def render_axes
          div(data_tabs: true) do
            div(role: "tablist", aria_label: "Axes") do
              @axes.each do |axis|
                selected = axis.id == @selected.id
                button(role: "tab", id: "axis-#{axis.id}-tab", aria_controls: "axis-#{axis.id}",
                       aria_selected: selected.to_s, tabindex: selected ? 0 : -1) { axis.name }
              end
            end

            @axes.each do |axis|
              div(role: "tabpanel", id: "axis-#{axis.id}", aria_labelledby: "axis-#{axis.id}-tab",
                  hidden: axis.id != @selected.id) do
                render_ranking(axis)
              end
            end
          end
        end

        def render_ranking(axis)
          ranked, unranked = axis.ranking

          ol(class: "card") do
            ranked.each.with_index(1) do |item, rank|
              li do
                span(class: "type-label") { format("%02d", rank) }
                plain item.name
              end
            end
            unranked.each do |item|
              li do
                span(class: "type-label") { "—" }
                plain item.name
                span(class: "type-label") { "Unranked" }
              end
            end
          end

          a(href: "/lists/#{@list.id}/axes/#{axis.id}/compare", class: "btn", data_variant: "primary") do
            "Compare on #{axis.name}"
          end
        end
      end
    end
  end
end
