# frozen_string_literal: true

module RankKing
  module Sources
    # What every source produces: one entry per item currently in the source.
    # external_id is how sync recognizes the same item across snapshots.
    Entry = Data.define(:external_id, :name, :url, :metadata) do
      def initialize(external_id:, name:, url: nil, metadata: {})
        super
      end
    end
  end
end

require_relative "sources/text"
require_relative "sources/youtube_playlist"

module RankKing
  module Sources
    ALL = {
      Text.kind => Text,
      YouTubePlaylist.kind => YouTubePlaylist,
    }.freeze

    def self.fetch(kind) = ALL.fetch(kind)
  end
end
