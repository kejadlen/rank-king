# frozen_string_literal: true

require_relative "test_helper"

require "minitest/autorun"

require_relative "../lib/rank_king/seed"

class TestSeed < Minitest::Test
  LOGIN = "alpha@example.com"

  def setup
    RankKing::DB[:results].delete
    RankKing::DB[:axes].delete
    RankKing::DB[:items].delete
    RankKing::DB[:lists].delete
    RankKing::DB[:users].delete
  end

  def test_seeds_lists_for_the_user
    RankKing::Seed.call(LOGIN)

    user = RankKing::User.first(login: LOGIN)
    names = RankKing::List.where(user_id: user.id).order(:id).map(&:name)
    assert_equal RankKing::Seed::LISTS.keys, names
    refute_empty RankKing::DB[:results].all
  end

  def test_leaves_a_user_with_lists_alone
    RankKing::Seed.call(LOGIN)
    RankKing::Seed.call(LOGIN)

    assert_equal RankKing::Seed::LISTS.size, RankKing::DB[:lists].count
  end
end
