# frozen_string_literal: true

require_relative "test_helper"

require "minitest/autorun"
require "rack/test"

require_relative "../lib/rank_king/web"

class TestYouTube < Minitest::Test
  include Rack::Test::Methods

  # The app, with the fake InnerTube in its config.
  class App < RankKing::Web
    singleton_class.attr_accessor :inner_tube

    private def config = RankKing::CONFIG.with(inner_tube: self.class.inner_tube)
  end

  def app = App.app

  LOGIN = "alpha@example.com"
  PLAYLIST = "PLabc123"
  COOKIE = "SID=sid; SAPISID=sapisid; __Secure-3PAPISID=3papisid"

  # InnerTube, as far as rank-king talks to it: the real client with its
  # requests answered here, in the shapes youtube.com gets. A playlist
  # pages two videos at a time, so fetching it has to follow its
  # continuations.
  class FakeInnerTube < RankKing::InnerTube
    attr_reader :calls
    attr_accessor :videos, :user_playlists, :error, :signed_out

    def initialize
      super
      @calls = []
      @videos = []
      @user_playlists = [["WL", "Watch later"], ["PLabc123", "Music"]]
    end

    private

    def request(cookie, body)
      @calls << [cookie, body]
      raise RankKing::InnerTube::Error, error if error
      return signed_out_page if signed_out
      return playlists_page if body[:browseId] == "FEplaylist_aggregation"

      page = body[:continuation].to_i
      items = videos[page * 2, 2].to_a.map { |id, title| video(id, title) }
      items << continuation(page + 1, first: page.zero?) if videos.size > (page + 1) * 2
      return signed_in("onResponseReceivedActions" => [{ "appendContinuationItemsAction" => { "continuationItems" => items } }]) if page.positive?

      list = { "playlistVideoListRenderer" => { "contents" => items } }
      signed_in("contents" => { "twoColumnBrowseResultsRenderer" => { "tabs" => [
        { "tabRenderer" => { "content" => { "sectionListRenderer" => { "contents" => [
          { "itemSectionRenderer" => { "contents" => [list] } },
        ] } } } },
      ] } })
    end

    def signed_in(body) = { "responseContext" => tracking("1"), **body }

    def tracking(logged_in) = { "serviceTrackingParams" => [{ "params" => [{ "key" => "logged_in", "value" => logged_in }] }] }

    def signed_out_page
      { "responseContext" => tracking("0"),
        "alerts" => [{ "alertRenderer" => { "type" => "ERROR", "text" => { "runs" => [{ "text" => "The playlist does not exist." }] } } }] }
    end

    def playlists_page
      lockups = user_playlists.map { |id, title|
        { "lockupViewModel" => { "contentId" => id, "contentType" => "LOCKUP_CONTENT_TYPE_PLAYLIST",
                                 "metadata" => { "lockupMetadataViewModel" => { "title" => { "content" => title } } } } }
      }
      signed_in("contents" => { "richGridRenderer" => { "contents" => lockups.map { { "richItemRenderer" => { "content" => _1 } } } } })
    end

    # A nil title stands for a deleted video, which is not playable.
    def video(id, title)
      { "playlistVideoRenderer" => {
        "videoId" => id, "isPlayable" => !title.nil?,
        "title" => { "runs" => [{ "text" => title || "[Deleted video]" }] },
        "shortBylineText" => { "runs" => [{ "text" => "A channel" }] },
      } }
    end

    # The first page wraps its continuation in a command executor; later
    # ones carry it bare.
    def continuation(token, first:)
      command = { "continuationCommand" => { "token" => token.to_s } }
      endpoint = first ? { "commandExecutorCommand" => { "commands" => [{}, command] } } : command
      { "continuationItemRenderer" => { "continuationEndpoint" => endpoint } }
    end
  end

  def setup
    header "Remote-User", LOGIN
    RankKing::DB[:results].delete
    RankKing::DB[:axes].delete
    RankKing::DB[:items].delete
    RankKing::DB[:lists].delete
    RankKing::DB[:users].delete

    @inner_tube = FakeInnerTube.new
    App.inner_tube = @inner_tube
  end

  def test_new_list_asks_for_a_cookie_before_the_playlists
    get "/lists/new"
    assert_includes last_response.body, %(<option value="YouTube">YouTube playlist</option>)
    assert_includes last_response.body, %(<textarea name="cookie")
    assert_includes last_response.body, %(data-playlists="/youtube/playlists")
    refute_includes last_response.body, %(name="playlist")
    assert_empty @inner_tube.calls
  end

  def test_a_pasted_cookie_lists_the_playlists
    playlists("Cookie: #{COOKIE}\n")
    assert last_response.ok?
    assert_includes last_response.body, %(<select name="playlist" required>)
    assert_includes last_response.body, %(<option value="WL">Watch later</option>)
    assert_includes last_response.body, %(<option value="PLabc123">Music</option>)
    refute_includes last_response.body, "<html"
    assert_equal [COOKIE, { browseId: "FEplaylist_aggregation" }], @inner_tube.calls.last
  end

  def test_listing_playlists_needs_the_form_token
    post "/youtube/playlists", { cookie: COOKIE }
    assert_equal 403, last_response.status
    assert_empty @inner_tube.calls
  end

  def test_a_cookie_with_nothing_to_sign_with_lists_nothing
    playlists("SID=sid; HSID=hsid")
    assert_includes last_response.body, "no SAPISID"
    assert_empty @inner_tube.calls
  end

  def test_says_when_there_are_no_playlists
    @inner_tube.user_playlists = []
    playlists(COOKIE)
    assert_includes last_response.body, "no playlists yet"
  end

  def test_says_when_youtube_signed_the_cookie_out
    @inner_tube.signed_out = true
    playlists(COOKIE)
    assert last_response.ok?
    assert_includes last_response.body, "YouTube signed the cookie out."
  end

  def test_authorization_signs_each_api_cookie
    at = 1_700_000_000
    sign = ->(value) { Digest::SHA1.hexdigest("#{at} #{value} https://www.youtube.com") }

    assert_equal "SAPISIDHASH #{at}_#{sign.("sapisid")} SAPISID3PHASH #{at}_#{sign.("3papisid")}",
      RankKing::InnerTube.authorization(COOKIE, at:)
  end

  def test_create_a_list_from_a_playlist
    @inner_tube.videos = [["v1", "First"], ["v2", nil], ["v3", "Third"], ["v4", "Fourth"], ["v1", "First again"]]

    create_list(playlist: PLAYLIST)
    assert last_response.redirect?

    list = RankKing::List.first
    assert_equal "YouTube", list.source_kind
    refute_nil list.synced_at
    assert_equal %w[First Third Fourth], names(list)
    assert_equal PLAYLIST, RankKing::DB[:youtube_sources].where(list_id: list.id).get(:playlist_id)
    assert_equal %w[v1 v3 v4], RankKing::DB[:youtube_items].order(:item_id).map(:video_id)
    first = RankKing::DB[:youtube_items].first(video_id: "v1")
    assert_equal "First", first[:title]
    assert_equal "A channel", first[:channel_title]
    assert_equal "https://i.ytimg.com/vi/v1/mqdefault.jpg", first[:thumbnail_url]

    assert_equal [{ browseId: "VLPLabc123" }, { continuation: "1" }, { continuation: "2" }], @inner_tube.calls.map(&:last)
    assert_equal [COOKIE], @inner_tube.calls.map(&:first).uniq
  end

  def test_create_a_list_from_watch_later
    @inner_tube.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: "WL")

    assert_equal %w[First Second], names(RankKing::List.first)
    assert_equal({ browseId: "VLWL" }, @inner_tube.calls.last.last)
  end

  def test_create_needs_a_cookie
    create_list(playlist: PLAYLIST, cookie: "SID=sid")
    assert_equal 422, last_response.status
    assert_equal 0, RankKing::List.count
    assert_empty @inner_tube.calls
  end

  def test_create_needs_a_playlist
    create_list(playlist: "not a playlist")
    assert_equal 422, last_response.status
    assert_equal 0, RankKing::List.count
  end

  def test_sync_adds_archives_and_restores_by_video
    @inner_tube.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)
    list = RankKing::List.first
    first, second = list.items_dataset.order(:id).all

    @inner_tube.videos = [["v1", "First, renamed"], ["v3", "Third"]]
    sync(list, cookie: "SAPISID=fresh")
    assert last_response.redirect?
    assert_equal ["First, renamed", "Third"], names(list)
    refute_nil second.reload.archived_at
    assert_equal "First, renamed", first.reload.name
    assert_equal "First, renamed", RankKing::DB[:youtube_items].first(item_id: first.id)[:title]
    assert_equal "SAPISID=fresh", @inner_tube.calls.last.first

    @inner_tube.videos = [["v2", "Second"]]
    sync(list)
    assert_equal %w[Second], names(list)
    assert_nil second.reload.archived_at
  end

  def test_sync_dialog_asks_for_a_cookie_and_shows_progress
    @inner_tube.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)

    get "/lists/#{RankKing::List.first.id}"
    assert_includes last_response.body, "Sync from YouTube"
    assert_includes last_response.body, %(<textarea name="cookie")
    assert_includes last_response.body, %(data-busy="Syncing…")
  end

  def test_sync_needs_a_cookie
    @inner_tube.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)
    list = RankKing::List.first
    @inner_tube.calls.clear

    sync(list, cookie: "")
    assert_equal 502, last_response.status
    assert_includes last_response.body, "no SAPISID"
    assert_empty @inner_tube.calls
  end

  def test_a_signed_out_cookie_archives_nothing
    @inner_tube.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)
    list = RankKing::List.first

    @inner_tube.signed_out = true
    sync(list)
    assert_equal 502, last_response.status
    assert_includes last_response.body, "YouTube: YouTube signed the cookie out."
    assert_equal %w[First Second], names(list)
  end

  def test_youtube_errors_are_reported
    @inner_tube.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)
    list = RankKing::List.first

    @inner_tube.error = "Request contains an invalid argument."
    sync(list)
    assert_equal 502, last_response.status
    assert_includes last_response.body, "Request contains an invalid argument."
    assert_equal %w[First Second], names(list)
  end

  def test_deleting_a_youtube_list
    @inner_tube.videos = [["v1", "First"], ["v2", "Second"]]
    create_list(playlist: PLAYLIST)
    list = RankKing::List.first

    csrf_post "/lists/#{list.id}/delete", {}, from: "/lists/#{list.id}/settings"
    assert last_response.redirect?
    assert_equal 0, RankKing::DB[:youtube_sources].count
    assert_equal 0, RankKing::DB[:youtube_items].count
  end

  private

  def names(list) = list.items_dataset.order(:id).map(:name)

  # Posts the cookie as app.js does, with the token the new-list form
  # carries for it.
  def playlists(cookie)
    get "/lists/new"
    token = last_response.body[/data-playlists="\/youtube\/playlists" data-csrf="([^"]+)"/, 1]
    post "/youtube/playlists", { cookie:, "_csrf" => token }
  end

  def create_list(playlist:, cookie: COOKIE)
    csrf_post "/lists", { name: "Videos", source: "YouTube", playlist:, cookie: }, from: "/lists/new"
  end

  def sync(list, cookie: COOKIE)
    csrf_post "/lists/#{list.id}/sync", { cookie: }, from: "/lists/#{list.id}"
  end

  def csrf_post(path, params, from:)
    get from
    token = last_response.body[/action="#{Regexp.escape(path)}".*?name="_csrf" value="([^"]+)"/m, 1]
    post path, params.merge("_csrf" => token)
  end
end
