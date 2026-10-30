# frozen_string_literal: true

require_relative "../inner_tube"
require_relative "../sync"
require_relative "../views/sources/youtube"

module RankKing
  module Sources
    # A list that follows one of the owner's YouTube playlists, read
    # through InnerTube, so private ones and Watch Later work too. Nothing
    # signs rank-king in for good: each fetch takes a youtube.com cookie
    # pasted in for it, and the whole playlist is fetched again.
    class YouTube
      # Which playlist each list follows, keyed by list_id.
      TABLE = :youtube_sources
      # Which video each item is, keyed by item_id.
      ITEMS = :youtube_items
      # Where the new-list form sends a pasted cookie for its choice of
      # playlists.
      PLAYLISTS_PATH = "/youtube/playlists"

      #: () -> String
      def self.title = "YouTube playlist"

      #: (List list, _InnerTubeConfig config) -> YouTube
      def self.for(list, config) = new(list, config)

      #: (csrf: Method) -> _Component
      def self.fields(csrf:) = Views::Sources::YouTubeFields.new(csrf:)

      # The new-list form's playlist picker, drawn from a pasted cookie. It
      # is a POST so the cookie stays out of URLs and logs.
      #: (Roda::RodaRequest r, _InnerTubeConfig config) -> void
      def self.routes(r, config)
        r.post PLAYLISTS_PATH.delete_prefix("/") do
          playlists(r.params["cookie"], config).call
        end
      end

      # The choice of playlists a pasted cookie opens. Whatever stops it
      # is said in the choice's place.
      #: (untyped text, _InnerTubeConfig config) -> _Component
      def self.playlists(text, config)
        Views::Sources::YouTubePlaylists.new(playlists: config.inner_tube.playlists(cookie(text)))
      rescue InnerTube::Error => e
        Views::Sources::YouTubePlaylists.new(playlists: nil, error: e.message)
      end

      #: (untyped text) -> String
      def self.cookie(text)
        InnerTube.cookie(text.to_s) or raise InnerTube::Error, "That cookie has no SAPISID to sign requests with."
      end

      # Follows the playlist chosen on the new-list form and fetches it
      # with the cookie pasted there.
      #: (List list, Hash[String, untyped] params, _InnerTubeConfig config) -> void
      def self.create(list, params, config)
        playlist_id = params["playlist"].to_s[/\A[\w-]+\z/] or raise Invalid, "Choose a playlist to follow."
        cookie = InnerTube.cookie(params["cookie"].to_s) or raise Invalid, "That cookie has no SAPISID to sign requests with."

        DB[TABLE].insert(list_id: list.id, playlist_id:)
        new(list, config).fetch(cookie)
      end

      #: (List list, _InnerTubeConfig config) -> void
      def initialize(list, config)
        @list = list
        @inner_tube = config.inner_tube
      end

      #: () -> String
      def label = "Sync from YouTube"

      #: (csrf: Method) -> _Component
      def form(csrf:) = Views::Sources::YouTube.new(list: @list, csrf:)

      # The dialog posts the cookie to fetch with.
      #: (Hash[String, untyped] params) -> void
      def sync(params)
        fetch(self.class.cookie(params["cookie"]))
      end

      #: (String cookie) -> Sync::Summary
      def fetch(cookie)
        # Kept for saved, which caches each video's details by its item.
        @videos = @inner_tube.playlist_videos(cookie, playlist_id).uniq(&:id).to_h { |video|
          [video.id, video] #: [String, InnerTube::Video]
        }
        entries = @videos.each_value.map { |video| Entry.new(key: video.id, name: video.title) }
        Sync.call(@list, entries, source: self)
      end

      #: () -> String
      def playlist_id = DB[TABLE].where(list_id: @list.id).get(:playlist_id).to_s

      #: () -> Hash[String, Item]
      def items_by_key
        video_ids = DB[ITEMS].where(item_id: Item.where(list_id: @list.id).select(:id)).to_hash(:item_id, :video_id)
        Item.where(id: video_ids.keys).all.to_h { |item|
          [video_ids.fetch(item.id).to_s, item] #: [String, Item]
        }
      end

      #: (Item item, Entry entry) -> void
      def saved(item, entry)
        video = @videos&.fetch(entry.key)
        DB[ITEMS].replace(
          item_id: item.id, video_id: entry.key, title: entry.name,
          channel_title: video&.channel_title, thumbnail_url: video&.thumbnail_url,
        )
      end
    end
  end
end
