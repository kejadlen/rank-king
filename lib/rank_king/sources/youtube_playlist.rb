# frozen_string_literal: true

require "uri"

module RankKing
  module Sources
    # A pull source: the videos in a YouTube playlist, including private ones,
    # read with the owner's OAuth token. (Watch Later is not readable through
    # the API, so it can't be used here.)
    class YouTubePlaylist
      # Placeholders YouTube returns for videos that are gone or hidden.
      UNAVAILABLE = ["Deleted video", "Private video"].freeze

      def self.kind = "youtube_playlist"
      def self.push? = false

      # Accepts a bare playlist ID or any URL with a list= parameter.
      def self.playlist_id(input)
        input = input.to_s.strip
        return input unless input.include?("/")

        URI.decode_www_form(URI(input).query.to_s).to_h.fetch("list", "")
      rescue URI::InvalidURIError
        ""
      end

      def initialize(config = {}, client:)
        @playlist_id = config.fetch("playlist_id")
        @client = client
      end

      def entries(_snapshot = nil)
        pages.flat_map {|page| page.fetch("items") }.filter_map {|item|
          snippet = item.fetch("snippet")
          next if UNAVAILABLE.include?(snippet["title"])

          video_id = item.dig("contentDetails", "videoId")
          Entry.new(
            external_id: video_id,
            name: snippet.fetch("title"),
            url: "https://www.youtube.com/watch?v=#{video_id}",
            metadata: {
              "channel" => snippet["videoOwnerChannelTitle"],
              "thumbnail" => snippet.dig("thumbnails", "medium", "url"),
            }.compact,
          )
        }.uniq(&:external_id)
      end

      private

      def pages
        Enumerator.new do |y|
          token = nil
          loop do
            params = { part: "snippet,contentDetails", playlistId: @playlist_id, maxResults: 50 }
            params[:pageToken] = token if token
            page = @client.get("playlistItems", params)
            y << page
            token = page["nextPageToken"] or break
          end
        end
      end
    end
  end
end
