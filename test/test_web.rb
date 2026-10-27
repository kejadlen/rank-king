# frozen_string_literal: true

require_relative "test_helper"

require "minitest/autorun"
require "rack/test"

require_relative "../lib/rank_king/web"

class TestWeb < Minitest::Test
  include Rack::Test::Methods

  def app = RankKing::Web.app

  LOGIN = "alpha@example.com"

  def setup
    header "Remote-User", LOGIN
    RankKing::DB[:results].delete
    RankKing::DB[:axes].delete
    RankKing::DB[:items].delete
    RankKing::DB[:lists].delete
    RankKing::DB[:users].delete
  end

  def test_root_shows_empty_state
    get "/"
    assert last_response.ok?
    assert_includes last_response.body, "No lists yet."
  end

  def test_create_list
    create_list(name: "Foods", items: "Pizza\nSushi\nTacos", axes: "Taste\nValue")
    assert last_response.redirect?

    list = RankKing::DB[:lists].first
    assert_equal "Foods", list[:name]

    items = RankKing::DB[:items].where(list_id: list[:id]).map { |i| i[:name] }
    assert_equal %w[Pizza Sushi Tacos], items

    axes = RankKing::DB[:axes].where(list_id: list[:id]).map { |a| a[:name] }
    assert_equal %w[Taste Value], axes
  end

  def test_create_list_rejects_empty_name
    create_list(name: "  ", items: "A\nB")
    assert_equal 422, last_response.status
  end

  def test_create_list_rejects_fewer_than_two_items
    create_list(name: "Solo", items: "OnlyOne")
    assert_equal 422, last_response.status
  end

  def test_create_list_without_axes
    create_list(name: "Simple", items: "A\nB", axes: "")
    assert last_response.redirect?

    list = RankKing::DB[:lists].first
    assert_equal 0, RankKing::DB[:axes].where(list_id: list[:id]).count
  end

  def test_show_list
    create_list(name: "Foods", items: "Pizza\nSushi", axes: "Taste")
    list = RankKing::DB[:lists].first

    get "/lists/#{list[:id]}"
    assert last_response.ok?
    assert_includes last_response.body, "Foods"
    assert_includes last_response.body, "Pizza"
    assert_includes last_response.body, "Sushi"
    assert_includes last_response.body, "Taste"
  end

  def test_show_list_404_for_nonexistent
    get "/lists/999999"
    assert_equal 404, last_response.status
  end

  def test_record_result
    create_list(name: "Foods", items: "Pizza\nSushi", axes: "Taste")
    list = RankKing::DB[:lists].first
    items = RankKing::DB[:items].where(list_id: list[:id]).all
    axis = RankKing::DB[:axes].first(list_id: list[:id])

    csrf_post "/lists/#{list[:id]}/results", {
      axis_id: axis[:id],
      winner_id: items[0][:id],
      loser_id: items[1][:id],
    }
    assert last_response.redirect?

    result = RankKing::DB[:results].first
    assert_equal axis[:id], result[:axis_id]
    assert_equal items[0][:id], result[:winner_id]
    assert_equal items[1][:id], result[:loser_id]
  end

  def test_record_result_rejects_same_item
    create_list(name: "Foods", items: "Pizza\nSushi", axes: "Taste")
    list = RankKing::DB[:lists].first
    item = RankKing::DB[:items].first(list_id: list[:id])
    axis = RankKing::DB[:axes].first(list_id: list[:id])

    csrf_post "/lists/#{list[:id]}/results", {
      axis_id: axis[:id],
      winner_id: item[:id],
      loser_id: item[:id],
    }
    assert_equal 422, last_response.status
  end

  def test_root_links_to_list
    create_list(name: "Foods", items: "Pizza\nSushi")
    list = RankKing::DB[:lists].first

    get "/"
    assert_includes last_response.body, "/lists/#{list[:id]}"
    assert_includes last_response.body, "Foods"
  end

  def test_csrf_rejects_post_without_token
    post "/lists", { name: "Nope", items: "A\nB" }
    assert_equal 403, last_response.status
  end

  def test_create_list_adds_a_text_source
    create_list(name: "Foods", items: "Pizza\nSushi")
    list = RankKing::List.first

    assert_equal "Text", list.source_kind
    assert_equal %w[Pizza Sushi], list.items.map(&:name)
  end

  def test_text_sync_dialog_lists_items_for_editing
    create_list(name: "Foods", items: "Pizza\nSushi")
    list = RankKing::List.first
    pizza = list.items.find { |i| i.name == "Pizza" }

    get "/lists/#{list.id}"
    assert_includes last_response.body, "Edit items"
    assert_includes last_response.body, %(action="/lists/#{list.id}/sync")
    assert_includes last_response.body, %(name="items[#{pizza.id}]" value="Pizza")
  end

  def test_text_sync_renames_archives_and_adds_by_id
    create_list(name: "Foods", items: "Pizza\nSushi\nTacos", axes: "Taste")
    list = RankKing::List.first
    pizza, sushi, tacos = list.items_dataset.order(:id).all

    csrf_post "/lists/#{list.id}/sync", {
      "items" => { pizza.id.to_s => "Pizza Margherita", sushi.id.to_s => "  ", tacos.id.to_s => "Tacos" },
      "new_items" => "Ramen\n\nCurry\n",
    }
    assert last_response.redirect?

    assert_equal "Pizza Margherita", pizza.reload.name
    refute_nil sushi.reload.archived_at
    assert_nil tacos.reload.archived_at
    assert_equal ["Pizza Margherita", "Tacos", "Ramen", "Curry"], list.items_dataset.order(:id).map(:name)

    get "/lists/#{list.id}"
    refute_includes last_response.body, "Sushi"
  end

  def test_text_sync_leaves_items_it_was_not_sent
    create_list(name: "Foods", items: "Pizza\nSushi")
    list = RankKing::List.first

    csrf_post "/lists/#{list.id}/sync", { "new_items" => "Tacos" }
    assert_equal %w[Pizza Sushi Tacos], list.items_dataset.order(:id).map(:name)
  end

  def test_record_result_rejects_archived_item
    create_list(name: "Foods", items: "Pizza\nSushi\nTacos", axes: "Taste")
    list = RankKing::List.first
    sushi = list.items.find { |i| i.name == "Sushi" }
    sushi.update(archived_at: Time.now)

    csrf_post "/lists/#{list.id}/results", {
      axis_id: list.axes.first.id,
      winner_id: sushi.id,
      loser_id: list.items.first.id,
    }
    assert_equal 422, last_response.status
  end

  def test_lists_belong_to_the_current_user
    create_list(name: "Foods", items: "Pizza\nSushi")

    assert_equal LOGIN, RankKing::List.first.user.login
  end

  def test_requires_login
    header "Remote-User", nil
    get "/"
    assert_equal 401, last_response.status
  end

  def test_lists_are_private
    as("alice@example.com") { create_list(name: "Alpaca", items: "A\nB") }
    assert_equal 1, RankKing::List.count
    list = RankKing::List.first

    as("bob@example.com") do
      get "/"
      refute_includes last_response.body, "Alpaca"

      get "/lists/#{list.id}"
      assert_equal 404, last_response.status
    end
  end

  private

  def as(login)
    header "Remote-User", login
    yield
  ensure
    header "Remote-User", LOGIN
  end

  def csrf_post(path, params = {})
    get "/"
    token = last_response.body[/name="_csrf" value="([^"]+)"/, 1]
    # The home page CSRF token is for /lists, we need one for the target path
    get "/lists/#{path.split("/")[2]}" if path.match?(%r{\A/lists/\d+/})
    token = last_response.body[/action="#{Regexp.escape(path)}".*?name="_csrf" value="([^"]+)"/m, 1] || token
    post path, params.merge("_csrf" => token)
  end

  def create_list(name:, items:, axes: "")
    get "/"
    token = last_response.body[/name="_csrf" value="([^"]+)"/, 1]
    post "/lists", {
      _csrf: token,
      name: name,
      items: items,
      axes: axes,
    }
  end
end
