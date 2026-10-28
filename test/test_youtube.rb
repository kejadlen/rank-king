# frozen_string_literal: true

require_relative "test_helper"

require "minitest/autorun"
require "rack/test"
require "uri"

require_relative "../lib/rank_king/web"

class TestYouTube < Minitest::Test
  include Rack::Test::Methods

  def app = RankKing::Web.app

  LOGIN = "alpha@example.com"
  PLAYLIST = "PLabc123"

  # Google, as far as rank-king talks to it. The playlist pages two videos
  # at a time, so fetching it has to follow nextPageToken.
  class FakeGoogle
    attr_reader :calls
    attr_accessor :videos, :playlists, :error

    def initialize
      @calls = []
      @videos = []
      @playlists = [["PLabc123", "Music"], ["PLdef456", "Talks"]]
    end

    def call(method, url, params, access_token)
      @calls << [method, url, params, access_token]
      raise RankKing::Google::Error, error if error

      case url
      when RankKing::Google::TOKEN_URL
        if params[:grant_type] == "authorization_code"
          { "refresh_token" => "refresh-#{params[:code]}" }
        else
          { "access_token" => "access-#{params[:refresh_token]}" }
        end
      when RankKing::Google::PLAYLISTS_URL
        { "items" => playlists.map { |id, title| { "id" => id, "snippet" => { "title" => title } } } }
      when RankKing::Google::PLAYLIST_ITEMS_URL
        page = params[:pageToken].to_i
        body = { "items" => videos[page * 2, 2].to_a.map { |id, title| item(id, title) } }
        body["nextPageToken"] = (page + 1).to_s if videos.size > (page + 1) * 2
        body
      end
    end

    private

    # A nil title stands for a deleted video, which has no owner.
    def item(id, title)
      snippet = { "title" => title || "Deleted video", "resourceId" => { "videoId" => id }, "thumbnails" => {} }
      if title
        snippet["videoOwnerChannelTitle"] = "A channel"
        snippet["thumbnails"] = {
          "default" => { "url" => "https://i.ytimg.com/vi/#{id}/default.jpg" },
          "medium" => { "url" => "https://i.ytimg.com/vi/#{id}/mqdefault.jpg" },
        }
      end
      { "snippet" => snippet }
    end
  end

  def setup
    header "Remote-User", LOGIN
    RankKing::DB[:results].delete
    RankKing::DB[:axes].delete
    RankKing::DB[:items].delete
    RankKing::DB[:lists].delete
    RankKing::DB[:users].delete

    @google = FakeGoogle.new
    RankKing::Google.transport = @google.method(:call)
  end

  def teardown
    RankKing::Google.transport = nil
  end

  def test_settings_offers_to_connect_google
    get "/settings"
    assert last_response.ok?
    assert_includes last_response.body, %(href="/settings/google/connect")
  end

  def test_settings_says_when_google_is_not_set_up
    unconfigured do
      get "/settings"
      refute_includes last_response.body, "/settings/google/connect"
      assert_includes last_response.body, "GOOGLE_CLIENT_ID"

      get "/settings/google/connect"
      assert_equal 404, last_response.status
    end
  end

  def test_connecting_google_keeps_a_refresh_token
    get "/settings/google/connect"
    assert last_response.redirect?
    location = URI(last_response.location)
    query = URI.decode_www_form(location.query).to_h
    assert_equal "accounts.google.com", location.host
    assert_equal "client-id", query["client_id"]
    assert_equal "http://example.org/settings/google/callback", query["redirect_uri"]
    assert_equal RankKing::Google::SCOPE, query["scope"]
    assert_equal "offline", query["access_type"]

    get "/settings/google/callback", { state: query["state"], code: "the-code" }
    assert_equal "/settings", URI(last_response.location).path
    assert_equal "refresh-the-code", user.google_account.refresh_token

    get "/settings"
    assert_includes last_response.body, %(action="/settings/google/disconnect")
  end

  def test_callback_needs_the_state_it_was_sent_with
    get "/settings/google/connect"
    get "/settings/google/callback", { state: "forged", code: "the-code" }

    assert_equal 403, last_response.status
    assert_nil user.google_account
  end

  def test_callback_without_a_connect_is_refused
    get "/settings/google/callback", { state: "", code: "the-code" }
    assert_equal 403, last_response.status
  end

  def test_declining_on_google_connects_nothing
    get "/settings/google/connect"
    state = URI.decode_www_form(URI(last_response.location).query).to_h["state"]
    get "/settings/google/callback", { state:, error: "access_denied" }

    assert_equal "/settings", URI(last_response.location).path
    assert_nil user.google_account
    assert_empty @google.calls
  end

  def test_disconnecting_google
    connect_google
    csrf_post "/settings/google/disconnect", {}, from: "/settings"

    assert last_response.redirect?
    assert_nil user.google_account
  end

  def test_new_list_asks_to_connect_google_first
    get "/lists/new"
    assert_includes last_response.body, %(<option value="YouTubePlaylist">YouTube playlist</option>)
    assert_includes last_response.body, %(<a href="/settings">your settings</a>)
    refute_includes last_response.body, %(name="playlist")
  end

  def test_new_list_offers_the_users_playlists
    connect_google
    get "/lists/new"
    assert_includes last_response.body, %(<select name="playlist" required>)
    assert_includes last_response.body, %(<option value="PLabc123">Music</option>)
    assert_includes last_response.body, %(<option value="PLdef456">Talks</option>)

    _, url, params, access_token = @google.calls.last
    assert_equal RankKing::Google::PLAYLISTS_URL, url
    assert_equal "true", params[:mine]
    assert_equal "access-refresh-the-code", access_token
  end

  def test_new_list_says_when_there_are_no_playlists
    connect_google
    @google.playlists = []
    get "/lists/new"
    assert_includes last_response.body, "no playlists yet"
  end

  def test_new_list_still_works_when_google_fails
    connect_google
    @google.error = "Token has been expired or revoked."
    get "/lists/new"
    assert last_response.ok?
    assert_includes last_response.body, "Token has been expired or revoked."
    assert_includes last_response.body, %(name="items")
  end

  def test_create_a_list_from_a_playlist
    connect_google
    @google.videos = [["v1", "First"], ["v2", nil], ["v3", "Third"], ["v4", "Fourth"], ["v1", "First again"]]

    create_list(playlist: PLAYLIST)
    assert last_response.redirect?

    list = RankKing::List.first
    assert_equal "YouTubePlaylist", list.source_kind
    refute_nil list.synced_at
    assert_equal %w[First Third Fourth], names(list)
    assert_equal PLAYLIST, RankKing::DB[:youtube_sources].where(list_id: list.id).get(:playlist_id)
    assert_equal %w[v1 v3 v4], RankKing::DB[:youtube_items].order(:item_id).map(:video_id)
    first = RankKing::DB[:youtube_items].first(video_id: "v1")
    assert_equal "First", first[:title]
    assert_equal "A channel", first[:channel_title]
    assert_equal "https://i.ytimg.com/vi/v1/mqdefault.jpg", first[:thumbnail_url]

    tokens = @google.calls.select { |_, url, _, _| url == RankKing::Google::TOKEN_URL }
    assert_equal "refresh-the-code", tokens.last[2][:refresh_token]
    pages = @google.calls.select { |_, url, _, _| url == RankKing::Google::PLAYLIST_ITEMS_URL }
    assert_equal 3, pages.size
    assert_equal ["access-refresh-the-code"], pages.map(&:last).uniq
  end

  def test_create_needs_google
    create_list(playlist: PLAYLIST)
    assert_equal 422, last_response.status
    assert_equal 0, RankKing::List.count
  end

  def test_create_needs_a_playlist
    connect_google
    create_list(playlist: "not a playlist")
    assert_equal 422, last_response.status
    assert_equal 0, RankKing::List.count
  end

  def test_sync_adds_archives_and_restores_by_video
    connect_google
    @google.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)
    list = RankKing::List.first
    first, second = list.items_dataset.order(:id).all

    @google.videos = [["v1", "First, renamed"], ["v3", "Third"]]
    sync(list)
    assert last_response.redirect?
    assert_equal ["First, renamed", "Third"], names(list)
    refute_nil second.reload.archived_at
    assert_equal "First, renamed", first.reload.name
    assert_equal "First, renamed", RankKing::DB[:youtube_items].first(item_id: first.id)[:title]

    @google.videos = [["v2", "Second"]]
    sync(list)
    assert_equal %w[Second], names(list)
    assert_nil second.reload.archived_at
  end

  def test_sync_dialog_shows_progress
    connect_google
    @google.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)

    get "/lists/#{RankKing::List.first.id}"
    assert_includes last_response.body, "Sync from YouTube"
    assert_includes last_response.body, %(data-busy="Syncing…")
  end

  def test_google_errors_are_reported
    connect_google
    @google.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)
    list = RankKing::List.first

    @google.error = "Token has been expired or revoked."
    sync(list)
    assert_equal 502, last_response.status
    assert_includes last_response.body, "Token has been expired or revoked."
    assert_equal %w[First Second], names(list)
  end

  def test_deleting_a_youtube_list
    connect_google
    @google.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)
    list = RankKing::List.first

    csrf_post "/lists/#{list.id}/delete", {}, from: "/lists/#{list.id}/settings"
    assert last_response.redirect?
    assert_equal 0, RankKing::DB[:youtube_sources].count
    assert_equal 0, RankKing::DB[:youtube_items].count
  end

  private

  def user = RankKing::User.first(login: LOGIN)

  # As if the server had no Google client.
  def unconfigured
    google = RankKing::Google.singleton_class
    google.alias_method :__configured?, :configured?
    google.define_method(:configured?) { false }
    yield
  ensure
    google.alias_method :configured?, :__configured?
    google.remove_method :__configured?
  end

  def connect_google
    get "/settings/google/connect"
    state = URI.decode_www_form(URI(last_response.location).query).to_h["state"]
    get "/settings/google/callback", { state:, code: "the-code" }
    @google.calls.clear
  end

  def names(list) = list.items_dataset.order(:id).map(:name)

  def create_list(playlist:)
    csrf_post "/lists", { name: "Videos", source: "YouTubePlaylist", playlist: }, from: "/lists/new"
  end

  def sync(list)
    csrf_post "/lists/#{list.id}/sync", {}, from: "/lists/#{list.id}"
  end

  def csrf_post(path, params, from:)
    get from
    token = last_response.body[/action="#{Regexp.escape(path)}".*?name="_csrf" value="([^"]+)"/m, 1]
    post path, params.merge("_csrf" => token)
  end
end
