# frozen_string_literal: true

module RankKing
  module Sources
    # What every source produces: one entry per item currently in the source.
    # key is how the source recognizes the same item across syncs (see
    # items_by_key); name is the item field any source has.
    # Signed in sig/rank_king/sources.rbs: a Data class.
    # @rbs skip
    Entry = Data.define(:key, :name)
  end
end

require_relative "sources/text"
require_relative "sources/youtube_playlist"

module RankKing
  module Sources
    # Every kind a list can be made from, in the order the new-list form
    # offers them. A list keeps its kind for good.
    KINDS = %w[Text YouTubePlaylist].freeze #: Array[String]

    # A list's source_kind names a class in this module.
    #: (String kind) -> _SourceClass
    def self.fetch(kind) = const_get(kind, false)
  end
end
