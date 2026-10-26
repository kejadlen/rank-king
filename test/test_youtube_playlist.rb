# frozen_string_literal: true

require_relative "test_helper"

require "minitest/autorun"

require_relative "../lib/rank_king/sources"

class TestYouTubePlaylist < Minitest::Test
  Source = RankKing::Sources::YouTubePlaylist

  class FakeClient
    attr_reader :requests

    def initialize(pages)
      @pages = pages
      @requests = []
    end

    def get(path, params)
      @requests << [path, params]
      @pages.fetch(params[:pageToken])
    end
  end

  def test_entries_follow_pages
    client = FakeClient.new(
      nil => { "items" => [video("a", "First")], "nextPageToken" => "p2" },
      "p2" => { "items" => [video("b", "Second")] },
    )
    entries = Source.new({ "playlist_id" => "PL1" }, client:).entries

    assert_equal %w[a b], entries.map(&:external_id)
    assert_equal %w[First Second], entries.map(&:name)
    assert_equal "https://www.youtube.com/watch?v=a", entries.first.url
    assert_equal({ "channel" => "Chan", "thumbnail" => "https://i.ytimg.com/a.jpg" }, entries.first.metadata)
    assert_equal "PL1", client.requests.first[1][:playlistId]
  end

  def test_entries_skip_unavailable_and_duplicate_videos
    client = FakeClient.new(nil => { "items" => [
      video("a", "First"), video("x", "Deleted video"), video("y", "Private video"), video("a", "First"),
    ] })

    assert_equal %w[a], Source.new({ "playlist_id" => "PL1" }, client:).entries.map(&:external_id)
  end

  def test_playlist_id_from_url_or_id
    assert_equal "PL1", Source.playlist_id("PL1")
    assert_equal "PL1", Source.playlist_id("https://www.youtube.com/playlist?list=PL1")
    assert_equal "PL1", Source.playlist_id("https://www.youtube.com/watch?v=a&list=PL1&index=2")
    assert_equal "", Source.playlist_id("https://www.youtube.com/watch?v=a")
  end

  private

  def video(id, title)
    {
      "snippet" => {
        "title" => title,
        "videoOwnerChannelTitle" => "Chan",
        "thumbnails" => { "medium" => { "url" => "https://i.ytimg.com/#{id}.jpg" } },
      },
      "contentDetails" => { "videoId" => id },
    }
  end
end
