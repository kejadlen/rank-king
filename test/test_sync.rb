# frozen_string_literal: true

require_relative "test_helper"

require "minitest/autorun"

require_relative "../lib/rank_king/sync"

class TestSync < Minitest::Test
  include RankKing

  # A synced source that recognizes its items by URL, standing in for a
  # kind that keeps its keys in its own table.
  class FakeSource
    attr_reader :calls

    def initialize(list)
      @list = list
      @calls = []
    end

    def items_by_key = RankKing::Item.where(list_id: @list.id).exclude(url: nil).to_hash(:url)

    def saved(item, entry)
      @calls << [item.id, entry.key]
    end
  end

  def setup
    DB[:results].delete
    DB[:axes].delete
    DB[:items].delete
    DB[:lists].delete
    DB[:users].delete

    user = User.create(login: "alpha@example.com")
    @list = List.create(name: "Videos", user_id: user.id, source_kind: "Fake")
    @source = FakeSource.new(@list)
  end

  def test_adds_new_entries
    summary = sync("a", "b")

    assert_equal Sync::Summary.new(added: 2, restored: 0, archived: 0), summary
    assert_equal %w[a b], names
    refute_nil @list.reload.synced_at
  end

  def test_archives_missing_entries_and_keeps_their_rows
    sync("a", "b")
    summary = sync("a")

    assert_equal 1, summary.archived
    assert_equal %w[a], names
    refute_nil Item.first(url: "https://example.com/b").archived_at
  end

  def test_restores_entries_that_come_back
    sync("a", "b")
    b = Item.first(url: "https://example.com/b")
    sync("a")
    summary = sync("a", "b")

    assert_equal 1, summary.restored
    assert_equal b.id, Item.first(url: "https://example.com/b").id
    assert_equal %w[a b], names
  end

  def test_refreshes_names_and_tells_the_source
    sync("a")
    item = Item.first
    Sync.call(@list, [entry("a", name: "Renamed")], source: @source)

    assert_equal "Renamed", item.reload.name
    assert_equal [[item.id, "https://example.com/a"]] * 2, @source.calls
  end

  private

  def entry(key, name: key)
    url = "https://example.com/#{key}"
    Sources::Entry.new(key: url, name:, url:)
  end

  def sync(*keys) = Sync.call(@list, keys.map {|key| entry(key) }, source: @source)

  def names = @list.items_dataset.order(:id).map(:name)
end
