# frozen_string_literal: true

require_relative "test_helper"

require "minitest/autorun"

require_relative "../lib/rank_king/sync"

class TestSync < Minitest::Test
  include RankKing

  def setup
    DB[:results].delete
    DB[:axes].delete
    DB[:items].delete
    DB[:lists].delete

    @list = List.create(name: "Videos")
  end

  def test_adds_new_entries
    summary = sync("A", "B")

    assert_equal Sync::Summary.new(added: 2, restored: 0, archived: 0), summary
    assert_equal %w[A B], names
    refute_nil @list.reload.synced_at
  end

  def test_archives_missing_entries_and_keeps_their_rows
    sync("A", "B")
    summary = sync("A")

    assert_equal 1, summary.archived
    assert_equal %w[A], names
    refute_nil Item.first(external_id: "B").archived_at
  end

  def test_restores_entries_that_come_back
    sync("A", "B")
    b = Item.first(external_id: "B")
    sync("A")
    summary = sync("A", "B")

    assert_equal 1, summary.restored
    assert_equal b.id, Item.first(external_id: "B").id
    assert_equal %w[A B], names
  end

  def test_refreshes_name_url_and_metadata
    Sync.call(@list, [Sources::Entry.new(external_id: "v1", name: "Old")])
    Sync.call(@list, [Sources::Entry.new(external_id: "v1", name: "New", url: "https://example.com/v1", metadata: { "thumb" => "t.jpg" })])

    item = Item.first(external_id: "v1")
    assert_equal "New", item.name
    assert_equal "https://example.com/v1", item.url
    assert_equal({ "thumb" => "t.jpg" }, item.metadata)
  end

  def test_text_source_strips_blank_and_duplicate_lines
    entries = Sources::Text.new.entries(" A \n\nB\nA\n")
    assert_equal %w[A B], entries.map(&:external_id)
  end

  private

  def sync(*lines) = Sync.call(@list, Sources::Text.new.entries(lines.join("\n")))

  def names = @list.items_dataset.order(:id).map(:name)
end
