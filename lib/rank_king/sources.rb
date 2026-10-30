# frozen_string_literal: true

module RankKing
  module Sources
    # What every source produces: one entry per item currently in the source.
    # key is how the source recognizes the same item across syncs (see
    # items_by_key); name is the item field any source has.
    # Signed in sig/rank_king/sources.rbs: a Data class.
    # @rbs skip
    Entry = Data.define(:key, :name)

    # Raised by a provider's create when the new-list form did not post enough
    # to set the list up; the message says what is missing.
    class Invalid < StandardError; end
  end
end

require_relative "sources/text"
require_relative "sources/youtube"

module RankKing
  module Sources
    # Every provider a list can be made from, by the name a list's
    # source_kind keeps, in the order the new-list form offers them. A list
    # keeps its provider for good.
    #: (Config config) -> Hash[String, _Provider]
    def self.providers(config) = {
      "Text" => Text::Provider.new,
      "YouTube" => YouTube::Provider.new(config.inner_tube),
    }
  end
end
