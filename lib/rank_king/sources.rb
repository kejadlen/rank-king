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

module RankKing
  module Sources
    # A list's source_kind names a class in this module.
    #: (String kind) -> _SourceClass
    def self.fetch(kind) = const_get(kind, false)
  end
end
