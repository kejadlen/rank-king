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
    create_list(name: "Foods", items: "Pizza\nSushi\nTacos", axes: %w[Taste Value])
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
    assert_equal "A list needs at least two items.\n", last_response.body
  end

  def test_create_list_without_axes
    create_list(name: "Simple", items: "A\nB", axes: [""])
    assert last_response.redirect?

    list = RankKing::DB[:lists].first
    assert_equal 0, RankKing::DB[:axes].where(list_id: list[:id]).count
  end

  def test_show_list
    create_list(name: "Foods", items: "Pizza\nSushi", axes: %w[Taste])
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
    create_list(name: "Foods", items: "Pizza\nSushi", axes: %w[Taste])
    list = RankKing::DB[:lists].first
    items = RankKing::DB[:items].where(list_id: list[:id]).all
    axis = RankKing::DB[:axes].first(list_id: list[:id])

    csrf_post "/lists/#{list[:id]}/results", {
      axis_id: axis[:id],
      winner_id: items[0][:id],
      loser_id: items[1][:id],
    }, from: "/lists/#{list[:id]}/axes/#{axis[:id]}/compare"
    assert last_response.redirect?

    result = RankKing::DB[:results].first
    assert_equal axis[:id], result[:axis_id]
    assert_equal items[0][:id], result[:winner_id]
    assert_equal items[1][:id], result[:loser_id]
  end

  def test_record_result_rejects_same_item
    create_list(name: "Foods", items: "Pizza\nSushi", axes: %w[Taste])
    list = RankKing::DB[:lists].first
    item = RankKing::DB[:items].first(list_id: list[:id])
    axis = RankKing::DB[:axes].first(list_id: list[:id])

    csrf_post "/lists/#{list[:id]}/results", {
      axis_id: axis[:id],
      winner_id: item[:id],
      loser_id: item[:id],
    }, from: "/lists/#{list[:id]}/axes/#{axis[:id]}/compare"
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
    create_list(name: "Foods", items: "Pizza\nSushi\nTacos", axes: %w[Taste])
    list = RankKing::List.first
    pizza, sushi, tacos = list.items_dataset.order(:id).all

    sync(list, {
      "items" => { pizza.id.to_s => "Pizza Margherita", sushi.id.to_s => "  ", tacos.id.to_s => "Tacos" },
      "new_items" => "Ramen\n\nCurry\n",
    })
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

    sync(list, { "new_items" => "Tacos" })
    assert_equal %w[Pizza Sushi Tacos], list.items_dataset.order(:id).map(:name)
  end

  def test_record_result_rejects_archived_item
    list, axis = create_list_with_axis(items: "Pizza\nSushi\nTacos")
    sushi = list.items.find { |i| i.name == "Sushi" }
    sushi.update(archived_at: Time.now)

    record_result(list, axis, winner: sushi, loser: list.items.first)
    assert_equal 422, last_response.status
  end

  def test_delete_list_with_archived_items
    list, = create_list_with_axis(items: "Pizza\nSushi\nTacos")
    list.items.first.update(archived_at: Time.now)

    csrf_post "/lists/#{list.id}/delete", {}, from: "/lists/#{list.id}/settings"
    assert_equal 0, RankKing::DB[:items].count
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

  def test_new_list_form
    get "/lists/new"
    assert last_response.ok?
    assert_includes last_response.body, "Typed list"
    assert_includes last_response.body, "Create list"
  end

  def test_create_list_rejects_unknown_source
    post "/lists", { name: "Games", source: "bgg", items: "A\nB", _csrf: csrf_token_for("/lists", from: "/lists/new") }
    assert_equal 422, last_response.status
  end

  def test_show_list_ranks_items_on_each_axis
    list, axis = create_list_with_axis(items: "Pizza\nSushi\nTacos")
    pizza, sushi, = list.items
    record_result(list, axis, winner: sushi, loser: pizza)

    get "/lists/#{list.id}"
    body = last_response.body[/role="tabpanel".*/m]
    assert_operator body.index("Sushi"), :<, body.index("Pizza")
    assert_operator body.index("Pizza"), :<, body.index("Tacos")
    assert_includes body, "Unranked"
    assert_includes body, "Compare on Taste"
  end

  def test_show_list_selects_the_requested_axis
    create_list(name: "Foods", items: "Pizza\nSushi", axes: %w[Taste Value])
    list = RankKing::List.first
    value = list.axes.last

    get "/lists/#{list.id}?axis=#{value.id}"
    assert_match(/id="axis-#{value.id}-tab"[^>]*aria-selected="true"/, last_response.body)
  end

  def test_show_list_without_axes_offers_the_first
    create_list(name: "Simple", items: "A\nB")
    list = RankKing::List.first

    get "/lists/#{list.id}"
    assert_includes last_response.body, %(action="/lists/#{list.id}/axes")
    assert_includes last_response.body, 'aria-label="New axis"'
  end

  def test_add_axis_from_the_list
    create_list(name: "Simple", items: "A\nB")
    list = RankKing::List.first

    csrf_post "/lists/#{list.id}/axes", { name: " Taste " }, from: "/lists/#{list.id}"
    axis = list.axes_dataset.first
    assert_equal "Taste", axis.name
    assert_equal "/lists/#{list.id}", URI(last_response.location).path
    assert_equal "axis=#{axis.id}", URI(last_response.location).query

    follow_redirect!
    assert_includes last_response.body, "Compare on Taste"
  end

  def test_add_axis_rejects_empty_name
    create_list(name: "Simple", items: "A\nB")
    list = RankKing::List.first

    csrf_post "/lists/#{list.id}/axes", { name: " " }, from: "/lists/#{list.id}"
    assert_equal 422, last_response.status
  end

  def test_compare_shows_a_pair
    list, axis = create_list_with_axis(items: "Pizza\nSushi")

    get "/lists/#{list.id}/axes/#{axis.id}/compare"
    assert last_response.ok?
    assert_includes last_response.body, "Which wins on Taste?"
    assert_includes last_response.body, "Pizza"
    assert_includes last_response.body, "Sushi"
  end

  def test_compare_404_for_an_axis_on_another_list
    _, axis = create_list_with_axis(items: "Pizza\nSushi")
    other, = create_list_with_axis(items: "A\nB")

    get "/lists/#{other.id}/axes/#{axis.id}/compare"
    assert_equal 404, last_response.status
  end

  def test_record_result_returns_to_compare
    list, axis = create_list_with_axis(items: "Pizza\nSushi")
    record_result(list, axis, winner: list.items[0], loser: list.items[1])

    assert_equal "/lists/#{list.id}/axes/#{axis.id}/compare", URI(last_response.location).path

    follow_redirect!
    assert_includes last_response.body, "Recent"
  end

  def test_settings_shows_the_fixed_source
    list, = create_list_with_axis(items: "Pizza\nSushi")

    get "/lists/#{list.id}/settings"
    assert last_response.ok?
    assert_includes last_response.body, "Typed list"
    refute_includes last_response.body, '<select name="source"'
  end

  def test_settings_renames_and_edits_axes
    create_list(name: "Foods", items: "Pizza\nSushi", axes: %w[Taste Value])
    list = RankKing::List.first
    taste, value = list.axes
    record_result(list, value, winner: list.items[0], loser: list.items[1])

    update_settings(list, name: "Meals", axis_ids: [taste.id], axes: ["Price", ""])
    assert last_response.redirect?

    list.reload
    assert_equal "Meals", list.name
    assert_equal %w[Taste Price], list.axes.map(&:name)
    assert_equal 0, RankKing::DB[:results].count
  end

  def test_settings_rejects_empty_name
    list, = create_list_with_axis(items: "Pizza\nSushi")
    update_settings(list, name: " ")
    assert_equal 422, last_response.status
  end

  def test_delete_list
    list, axis = create_list_with_axis(items: "Pizza\nSushi")
    record_result(list, axis, winner: list.items[0], loser: list.items[1])

    csrf_post "/lists/#{list.id}/delete", {}, from: "/lists/#{list.id}/settings"
    assert last_response.redirect?

    %i[lists items axes results].each { |table| assert_equal 0, RankKing::DB[table].count, table }
  end

  def test_settings_are_private
    list = as("alice@example.com") { create_list_with_axis(items: "A\nB").first }

    get "/lists/#{list.id}/settings"
    assert_equal 404, last_response.status
  end

  private

  def create_list_with_axis(items:)
    create_list(name: "Foods", items: items, axes: %w[Taste])
    list = RankKing::List.order(:id).last
    [list, list.axes.first]
  end

  def record_result(list, axis, winner:, loser:)
    csrf_post "/lists/#{list.id}/results",
              { axis_id: axis.id, winner_id: winner.id, loser_id: loser.id },
              from: "/lists/#{list.id}/axes/#{axis.id}/compare"
  end

  def sync(list, params)
    csrf_post "/lists/#{list.id}/sync", params, from: "/lists/#{list.id}"
  end

  def update_settings(list, name:, axis_ids: list.axes.map(&:id), axes: [])
    csrf_post "/lists/#{list.id}/settings", { name: name, axis_ids: axis_ids, axes: axes },
              from: "/lists/#{list.id}/settings"
  end

  def csrf_token_for(path, from:)
    get from
    last_response.body[/action="#{Regexp.escape(path)}".*?name="_csrf" value="([^"]+)"/m, 1]
  end

  def as(login)
    header "Remote-User", login
    yield
  ensure
    header "Remote-User", LOGIN
  end

  # Posts with the CSRF token of the form on page `from` that targets `path`.
  def csrf_post(path, params = {}, from:)
    post path, params.merge("_csrf" => csrf_token_for(path, from: from))
  end

  def create_list(name:, items:, axes: [])
    csrf_post "/lists", { name: name, source: "Text", items: items, axes: axes }, from: "/lists/new"
  end
end
