# frozen_string_literal: true

module RankKing
  module Sources
    # What every source produces: one entry per item currently in the source.
    # external_id is how sync recognizes the same item across snapshots.
    # Signed in sig/rank_king/sources.rbs: a Data class.
    # @rbs skip
    Entry = Data.define(:external_id, :name, :url, :metadata)
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
