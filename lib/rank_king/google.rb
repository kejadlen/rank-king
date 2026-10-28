# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

require_relative "config"

module RankKing
  # The Google APIs rank-king calls: OAuth, to connect a user's account,
  # and the YouTube Data API, to read their playlists.
  module Google
    # Google refused a request, or answered with something unexpected.
    class Error < StandardError; end

    # A video in a playlist, as YouTube describes it.
    # Signed in sig/rank_king/google.rbs: a Data class.
    # @rbs skip
    Video = Data.define(:id, :title, :channel_title, :thumbnail_url)

    AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_URL = "https://oauth2.googleapis.com/token"
    PLAYLISTS_URL = "https://www.googleapis.com/youtube/v3/playlists"
    PLAYLIST_ITEMS_URL = "https://www.googleapis.com/youtube/v3/playlistItems"
    SCOPE = "https://www.googleapis.com/auth/youtube.readonly"

    # Makes one request and returns its JSON body: a POST of a form, or
    # a GET with a query, authorized by the access token when there is
    # one. Tests swap it for canned answers.
    singleton_class.attr_writer :transport

    #: () -> ^(Symbol, String, Hash[Symbol, String], String?) -> Hash[String, untyped]
    def self.transport
      @transport ||= ->(method, url, params, access_token) { request(method, url, params, access_token) }
    end

    # Where to send the user to grant read access to their YouTube
    # account. prompt=consent makes Google send a refresh token every time.
    #: (redirect_uri: String, state: String) -> String
    def self.authorize_url(redirect_uri:, state:)
      query = URI.encode_www_form(
        client_id: CONFIG.google_client_id, redirect_uri:, state:, scope: SCOPE,
        response_type: "code", access_type: "offline", prompt: "consent",
      )
      "#{AUTH_URL}?#{query}"
    end

    # Trades the code Google sent back for a refresh token.
    #: (String code, redirect_uri: String) -> String
    def self.refresh_token(code, redirect_uri:)
      body = transport.call(:post, TOKEN_URL, { **client, code:, redirect_uri:, grant_type: "authorization_code" }, nil)
      body.fetch("refresh_token") { raise Error, "Google sent no refresh token" }
    end

    #: (String refresh_token) -> String
    def self.access_token(refresh_token)
      body = transport.call(:post, TOKEN_URL, { **client, refresh_token:, grant_type: "refresh_token" }, nil)
      body.fetch("access_token") { raise Error, "Google sent no access token" }
    end

    # The user's own playlists, as [playlist id, title]. YouTube leaves
    # out Watch Later and Liked videos.
    #: (String access_token) -> Array[[String, String]]
    def self.playlists(access_token)
      pages(access_token, PLAYLISTS_URL, { part: "snippet", mine: "true" }).map { |item|
        [item.fetch("id"), item.dig("snippet", "title").to_s] #: [String, String]
      }
    end

    # The videos in a playlist, in playlist order. Deleted videos, and
    # private ones the user cannot see, carry no owner and are left out.
    #: (String access_token, String playlist_id) -> Array[Video]
    def self.playlist_videos(access_token, playlist_id)
      items = pages(access_token, PLAYLIST_ITEMS_URL, { part: "snippet", playlistId: playlist_id })
      items.filter_map { |item|
        snippet = item.fetch("snippet")
        channel_title = snippet["videoOwnerChannelTitle"]
        next unless channel_title

        Video.new(
          id: snippet.dig("resourceId", "videoId"),
          title: snippet.fetch("title"),
          channel_title:,
          thumbnail_url: thumbnail_url(snippet["thumbnails"] || {}),
        )
      }
    end

    # The medium thumbnail (320×180), or the nearest size there is.
    #: (Hash[String, untyped] thumbnails) -> String?
    def self.thumbnail_url(thumbnails)
      size = %w[medium high default standard maxres].find { |name| thumbnails.key?(name) }
      size && thumbnails.dig(size, "url")
    end

    # Every item of a YouTube list endpoint, following its pages.
    #: (String access_token, String url, Hash[Symbol, String] query) -> Array[Hash[String, untyped]]
    def self.pages(access_token, url, query)
      items = [] #: Array[Hash[String, untyped]]
      page = nil #: String?
      loop do
        params = { **query, maxResults: "50" } #: Hash[Symbol, String]
        params[:pageToken] = page if page
        body = transport.call(:get, url, params, access_token)

        items.concat(body["items"] || [])
        page = body["nextPageToken"]
        break unless page
      end
      items
    end

    #: () -> Hash[Symbol, String]
    def self.client
      { client_id: CONFIG.google_client_id, client_secret: CONFIG.google_client_secret }
    end

    #: (Symbol method, String url, Hash[Symbol, String] params, String? access_token) -> Hash[String, untyped]
    def self.request(method, url, params, access_token)
      uri = URI(url)
      request = if method == :post
        Net::HTTP::Post.new(uri).tap do |post|
          post.set_form_data(params)
        end
      else
        uri.query = URI.encode_www_form(params)
        Net::HTTP::Get.new(uri)
      end
      request["Authorization"] = "Bearer #{access_token}" if access_token

      response = Net::HTTP.start(uri.hostname.to_s, uri.port, use_ssl: true) { |http| http.request(request) }
      body = JSON.parse(response.body.to_s)
      return body if response.is_a?(Net::HTTPSuccess)

      error = body["error"]
      message = error.is_a?(Hash) ? error["message"] : body["error_description"] || error
      raise Error, message || "HTTP #{response.code}"
    rescue JSON::ParserError
      raise Error, "Google answered HTTP #{response&.code} with no JSON"
    end
  end
end
