# frozen_string_literal: true

require_relative "../views/sources/text"

module RankKing
  module Sources
    # A source whose items are typed in by hand. Its sync is an edit dialog
    # over the list's items, which matches them by id, so there is nothing
    # to fetch and no table of its own.
    class Text
      #: (List list) -> Text
      def self.for(list) = new(list)

      #: () -> String
      def self.title = "Typed list"

      #: (User user) -> _Component
      def self.fields(user) = Views::Sources::TextFields.new

      # Adds the items typed into the new-list form, of which there must
      # be at least two.
      #: (List list, Hash[String, untyped] params) -> bool
      def self.create(list, params)
        names = params["items"].to_s.lines.map(&:strip).reject(&:empty?)
        return false if names.size < 2

        names.each { |name| Item.create(list_id: list.id, name:) }
        true
      end

      #: (List list) -> void
      def initialize(list)
        @list = list
      end

      #: () -> String
      def label = "Edit items"

      #: (csrf: Method) -> _Component
      def form(csrf:) = Views::Sources::Text.new(list: @list, csrf:)

      # Applies the dialog: each submitted name renames the item with that
      # id, a blank name archives it, and each line of new_items adds one.
      #: (Hash[String, untyped] params, ?now: Time) -> void
      def sync(params, now: Time.now)
        items = params["items"]
        names = items.is_a?(Hash) ? items : {} #: Hash[String, untyped]
        added = params["new_items"].to_s.lines.map(&:strip).reject(&:empty?)

        DB.transaction do
          @list.items.each do |item|
            name = names[item.id.to_s]
            next unless name.is_a?(String)

            name = name.strip
            if name.empty?
              item.update(archived_at: now)
            elsif name != item.name
              item.update(name:)
            end
          end

          added.each {|name| Item.create(list_id: @list.id, name:) }
        end
      end
    end
  end
end
