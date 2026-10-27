# frozen_string_literal: true

require "phlex"

module RankKing
  module Views
    # Axes as removable tags. Saved axes post their ids as `axis_ids[]`,
    # new ones post their names as `axes[]`. The trailing input is itself
    # an `axes[]` field, so a name typed there is kept even without
    # public/js/app.js, which turns each Enter into a tag.
    class AxisTags < Phlex::HTML
      def initialize(axes: [], hint: nil)
        @axes = axes
        @hint = hint
      end

      def view_template
        fieldset(data_tags: true) do
          legend { "Axes" }
          div(class: "tag-set") do
            @axes.each do |axis|
              span(class: "tag") do
                plain axis.name
                input(type: "hidden", name: "axis_ids[]", value: axis.id)
                button(type: "button", aria_label: "Remove #{axis.name}") { "×" }
              end
            end
            span(class: "tag", data_dashed: true) do
              input(type: "text", name: "axes[]", placeholder: "+ Axis", aria_label: "New axis")
            end
          end
          small { @hint } if @hint
        end
      end
    end
  end
end
