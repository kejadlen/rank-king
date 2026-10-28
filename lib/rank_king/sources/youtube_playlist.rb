# frozen_string_literal: true

require_relative "../google"
require_relative "../sync"
require_relative "../views/sources/youtube_playlist"

module RankKing
  module Sources
    # A list that follows one of the owner's YouTube playlists, read
    # through their connected Google account, so private ones work too.
    # Each sync fetches the whole playlist again.
    class YouTubePlaylist
      # Which playlist each list follows, keyed by list_id.
      TABLE = :youtube_sources
      # Which video each item is, keyed by item_id.
      ITEMS = :youtube_items

      #: () -> String
      def self.title = "YouTube playlist"

      #: (List list) -> YouTubePlaylist
      def self.for(list) = new(list)

      # A choice of the user's playlists, fetched as the form is drawn. A
      # Google error says so in place of the choice rather than failing
      # the whole form.
      #: (User user) -> _Component
      def self.fields(user)
        account = user.google_account
        playlists = account && Google.playlists(Google.access_token(account.refresh_token))
        Views::Sources::YouTubePlaylistFields.new(playlists:, configured: Google.configured?)
      rescue Google::Error => e
        Views::Sources::YouTubePlaylistFields.new(playlists: nil, configured: true, error: e.message)
      end

      # Follows the playlist chosen on the new-list form and fetches it.
      #: (List list, Hash[String, untyped] params) -> bool
      def self.create(list, params)
        playlist_id = params["playlist"].to_s[/\A[\w-]+\z/]
        return false unless playlist_id && list.user.google_account

        DB[TABLE].insert(list_id: list.id, playlist_id:)
        new(list).fetch
        true
      end

      #: (List list) -> void
      def initialize(list)
        @list = list
      end

      #: () -> String
      def label = "Sync from YouTube"

      #: (csrf: Method) -> _Component
      def form(csrf:) = Views::Sources::YouTubePlaylist.new(list: @list, csrf:)

      # The dialog posts nothing to apply: syncing is fetching.
      #: (Hash[String, untyped] params) -> void
      def sync(params)
        fetch
      end

      #: () -> Sync::Summary
      def fetch
        account = @list.user.google_account
        raise Google::Error, "Connect Google in settings to sync this list" unless account

        access_token = Google.access_token(account.refresh_token)
        videos = Google.playlist_videos(access_token, playlist_id).uniq { |video_id, _| video_id }
        entries = videos.map { |video_id, title| Entry.new(key: video_id, name: title) }
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
        DB[ITEMS].replace(item_id: item.id, video_id: entry.key)
      end
    end
  end
end
