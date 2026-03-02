# frozen_string_literal: true

# Tests ported from https://github.com/philihp/openskill.js/tree/main/src/__tests__

require "minitest/autorun"
require_relative "../lib/open_skill"

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/statistics/v.test.ts
# https://github.com/philihp/openskill.js/blob/main/src/__tests__/statistics/w.test.ts
# https://github.com/philihp/openskill.js/blob/main/src/__tests__/statistics/vt.test.ts
# https://github.com/philihp/openskill.js/blob/main/src/__tests__/statistics/wt.test.ts
class TestStatistics < Minitest::Test
  # JS expected values come from the `gaussian` npm package which uses a
  # Numerical Recipes erfc approximation. Ruby's Math.erf is higher
  # precision, so we assert_in_delta instead of exact equality.

  def test_v_1_2
    assert_in_delta 1.5251352044082924, OpenSkill::Statistics.v(1, 2), 1e-6
  end

  def test_v_0_2
    assert_in_delta 2.3732157475120528, OpenSkill::Statistics.v(0, 2), 1e-6
  end

  def test_v_0_neg1
    assert_in_delta 0.2875999734906994, OpenSkill::Statistics.v(0, -1), 1e-6
  end

  def test_v_denominator_less_than_threshold
    assert_equal 10, OpenSkill::Statistics.v(0, 10)
  end

  def test_w_1_2
    assert_in_delta 0.8009021873172315, OpenSkill::Statistics.w(1, 2), 1e-6
  end

  def test_w_0_2
    assert_in_delta 0.8857214892150859, OpenSkill::Statistics.w(0, 2), 1e-5
  end

  def test_w_0_neg1
    assert_in_delta 0.3703137182425503, OpenSkill::Statistics.w(0, -1), 1e-6
  end

  def test_w_denominator_less_than_threshold
    assert_equal 0, OpenSkill::Statistics.w(0, 10)
  end

  def test_w_tiny_denom_negative_x
    assert_equal 1, OpenSkill::Statistics.w(-1, 10)
  end

  def test_vt_small_b_small_x
    assert_equal 1100, OpenSkill::Statistics.vt(-1000, -100)
  end

  def test_vt_small_b_big_x
    assert_equal(-1100, OpenSkill::Statistics.vt(1000, -100))
  end

  def test_vt_big_b_small_x
    assert_in_delta 0.79788, OpenSkill::Statistics.vt(-1000, 1000), 0.001
  end

  def test_vt_big_b_big_x
    assert_in_delta 0, OpenSkill::Statistics.vt(0, 1000), 0.001
  end

  def test_wt_1_2
    assert_in_delta 0.38385826878672835, OpenSkill::Statistics.wt(1, 2), 1e-6
  end

  def test_wt_0_2
    assert_in_delta 0.22625869547437663, OpenSkill::Statistics.wt(0, 2), 1e-6
  end

  def test_wt_0_neg1
    assert_equal 1, OpenSkill::Statistics.wt(0, -1)
  end

  def test_wt_0_0
    assert_equal 1.0, OpenSkill::Statistics.wt(0, 0)
  end

  def test_wt_0_10
    assert_in_delta 0, OpenSkill::Statistics.wt(0, 10), 0.001
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/constants.test.ts
class TestModel < Minitest::Test
  def test_z_defaults_to_3
    model = OpenSkill::Model.new
    assert_equal 3, model.z
  end

  def test_z_accepts_override
    model = OpenSkill::Model.new(z: 2)
    assert_equal 2, model.z
    assert_equal 6.25, model.beta
    assert_equal 39.0625, model.beta_sq
  end

  def test_mu_defaults_to_25
    model = OpenSkill::Model.new
    assert_equal 25, model.mu
  end

  def test_mu_accepts_override
    model = OpenSkill::Model.new(mu: 300)
    assert_equal 50, model.beta
    assert_equal 2500, model.beta_sq
    assert_equal 3, model.z
  end

  def test_tau_defaults_to_nil
    assert_nil OpenSkill::Model.new.tau
  end

  def test_tau_accepts_override
    model = OpenSkill::Model.new(tau: 0.0042)
    assert_equal 0.0042, model.tau
  end

  def test_sigma_default
    assert_in_delta 8.333333333333334, OpenSkill::Model.new.sigma
  end

  def test_sigma_accepts_override
    model = OpenSkill::Model.new(sigma: 7)
    assert_equal 3.5, model.beta
    assert_equal 12.25, model.beta_sq
  end

  def test_epsilon_default
    assert_equal 0.0001, OpenSkill::Model.new.epsilon
  end

  def test_epsilon_accepts_override
    model = OpenSkill::Model.new(epsilon: 0.001)
    assert_equal 0.001, model.epsilon
  end

  def test_beta_default
    assert_in_delta 4.166666666666667, OpenSkill::Model.new.beta
  end

  def test_beta_accepts_override
    model = OpenSkill::Model.new(beta: 100)
    assert_equal 100, model.beta
    assert_equal 10000, model.beta_sq
  end

  def test_beta_sq_default
    assert_in_delta 17.361111111111114, OpenSkill::Model.new.beta_sq
  end

  def test_limit_sigma_defaults_false
    refute OpenSkill::Model.new.limit_sigma
  end

  def test_limit_sigma_accepts_flag
    model = OpenSkill::Model.new(limit_sigma: true)
    assert model.limit_sigma
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/rating.test.ts
class TestRating < Minitest::Test
  def test_defaults_mu_to_25
    r = OpenSkill::Model.new.rating
    assert_equal 25.0, r.mu
  end

  def test_defaults_sigma_to_8_333
    r = OpenSkill::Model.new.rating
    assert_in_delta 8.333, r.sigma, 0.001
  end

  def test_accepts_new_mu
    r = OpenSkill::Model.new(mu: 42).rating
    assert_equal 42, r.mu
    assert_in_delta 42.0 / 3, r.sigma, 0.001
  end

  def test_accepts_new_sigma
    r = OpenSkill::Model.new(sigma: 6.283185).rating
    assert_equal 25, r.mu
    assert_equal 6.283185, r.sigma
  end

  def test_mu_of_zero
    r = OpenSkill::Model.new(mu: 0).rating
    assert_equal 0, r.mu
    assert_equal 0, r.sigma
  end

  def test_sigma_of_zero
    r = OpenSkill::Model.new(sigma: 0).rating
    assert_equal 25, r.mu
    assert_equal 0, r.sigma
  end

  def test_different_z
    r = OpenSkill::Model.new(z: 5).rating
    assert_equal 25, r.mu
    assert_equal 5, r.sigma
  end

  def test_different_z_and_mu
    r = OpenSkill::Model.new(mu: 15, z: 3).rating
    assert_equal 15, r.mu
    assert_equal 5, r.sigma
  end

  def test_different_z_and_sigma
    r = OpenSkill::Model.new(sigma: 5, z: 3).rating
    assert_equal 25, r.mu
    assert_equal 5, r.sigma
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/ordinal.test.ts
class TestOrdinal < Minitest::Test
  def test_converts_rating_to_ordinal
    r = OpenSkill::Rating.new(5.0, 2.0)
    assert_equal(-1.0, OpenSkill::Model.new.ordinal(r))
  end

  def test_respects_alpha_and_target
    r = OpenSkill::Model.new(mu: 24.0, sigma: 6.0).rating
    result = OpenSkill::Model.new(alpha: 24.0, target: 1500.0).ordinal(r)
    assert_equal 1644.0, result
  end

  def test_respects_custom_z
    r = OpenSkill::Model.new(mu: 24.0, sigma: 6.0, z: 2).rating
    result = OpenSkill::Model.new(z: 2).ordinal(r)
    assert_equal 12.0, result
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/util/score.test.ts
class TestScore < Minitest::Test
  def test_returns_1_on_wins
    assert_equal 1.0, OpenSkill::Util.score(2, 1)
  end

  def test_returns_1_on_big_win
    assert_equal 1.0, OpenSkill::Util.score(34, 6)
  end

  def test_returns_0_on_losses
    assert_equal 0.0, OpenSkill::Util.score(1, 2)
  end

  def test_returns_0_on_big_loss
    assert_equal 0.0, OpenSkill::Util.score(3, 58)
  end

  def test_returns_half_on_ties
    assert_equal 0.5, OpenSkill::Util.score(1, 1)
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/util/rankings.test.ts
class TestRankings < Minitest::Test
  def test_ranks_0_element_array
    assert_equal [], OpenSkill::Util.rankings([], nil)
  end

  def test_ranks_0_element_with_reordering
    assert_equal [], OpenSkill::Util.rankings([], [])
  end

  def test_ranks_1_element_without_reordering
    assert_equal [0], OpenSkill::Util.rankings([:a], nil)
  end

  def test_ranks_1_element_with_reordering
    assert_equal [0], OpenSkill::Util.rankings([:a], [1])
  end

  def test_ranks_given_nil
    assert_equal [0, 1, 2, 3], OpenSkill::Util.rankings([:a, :b, :c, :d], nil)
  end

  def test_ranks_given_incremental
    assert_equal [0, 1, 2, 3], OpenSkill::Util.rankings([:a, :b, :c, :d], [1, 2, 3, 4])
  end

  def test_ranks_with_ties_at_start
    assert_equal [0, 0, 2, 3], OpenSkill::Util.rankings([:a, :b, :c, :d], [1, 1, 3, 4])
  end

  def test_ranks_with_ties_at_end
    assert_equal [0, 1, 2, 2], OpenSkill::Util.rankings([:a, :b, :c, :d], [1, 2, 3, 3])
  end

  def test_ranks_with_ties_in_middle
    assert_equal [0, 1, 1, 3], OpenSkill::Util.rankings([:a, :b, :c, :d], [1, 2, 2, 4])
  end

  def test_ranks_sparse_scores
    assert_equal [0, 1, 2, 2, 4], OpenSkill::Util.rankings([:a, :b, :c, :d, :e], [14, 32, 47, 47, 48])
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/util/ladder-pairs.test.ts
class TestLadderPairs < Minitest::Test
  def test_0_elements
    assert_equal [[]], OpenSkill::Util.ladder_pairs([])
  end

  def test_1_element
    assert_equal [[]], OpenSkill::Util.ladder_pairs([1])
  end

  def test_2_elements
    assert_equal [[2], [1]], OpenSkill::Util.ladder_pairs([1, 2])
  end

  def test_3_elements
    assert_equal [[2], [1, 3], [2]], OpenSkill::Util.ladder_pairs([1, 2, 3])
  end

  def test_4_elements
    assert_equal [[2], [1, 3], [2, 4], [3]], OpenSkill::Util.ladder_pairs([1, 2, 3, 4])
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/util/team-rating.test.ts
class TestTeamRating < Minitest::Test
  def setup
    @model = OpenSkill::Model.new
  end

  def test_aggregates_all_players
    r = @model.rating
    team1 = [r]
    team2 = [r, r]
    result = OpenSkill::Util.team_rating([team1, team2])
    assert_equal [25, 69.44444444444446, team1, 0], result[0].to_a
    assert_equal [50, 138.8888888888889, team2, 1], result[1].to_a
  end

  def test_aggregates_5v5
    r = @model.rating
    result = OpenSkill::Util.team_rating([[r] * 5, [r] * 5])
    assert_in_delta 125, result[0].mu
    assert_in_delta 125, result[1].mu
    assert_in_delta 347.22, result[0].sigma_sq, 0.01
    assert_in_delta 347.22, result[1].sigma_sq, 0.01
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/util/util-c.test.ts
class TestUtilC < Minitest::Test
  def setup
    @model = OpenSkill::Model.new
  end

  def test_util_c_computes
    r = @model.rating
    team1 = [r]
    team2 = [r, r]
    team_ratings = OpenSkill::Util.team_rating([team2, team1])
    c = OpenSkill::Util.util_c(team_ratings, @model.beta_sq)
    assert_in_delta 15.590239, c, 0.001
  end

  def test_util_c_5v5
    r = @model.rating
    team_ratings = OpenSkill::Util.team_rating([[r] * 5, [r] * 5])
    c = OpenSkill::Util.util_c(team_ratings, @model.beta_sq)
    assert_in_delta 27.003, c, 0.001
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/util/util-sum-q.test.ts
class TestUtilSumQ < Minitest::Test
  def setup
    @model = OpenSkill::Model.new
  end

  def test_util_sum_q_computes
    r = @model.rating
    team1 = [r]
    team2 = [r, r]
    team_ratings = OpenSkill::Util.team_rating([team1, team2])
    c = OpenSkill::Util.util_c(team_ratings, @model.beta_sq)
    sum_q = OpenSkill::Util.util_sum_q(team_ratings, c)
    assert_equal [29.67892702634643, 24.70819334370875], sum_q
  end

  def test_util_sum_q_5v5
    r = @model.rating
    team_ratings = OpenSkill::Util.team_rating([[r] * 5, [r] * 5])
    c = OpenSkill::Util.util_c(team_ratings, @model.beta_sq)
    sum_q = OpenSkill::Util.util_sum_q(team_ratings, c)
    assert_in_delta 204.84, sum_q[0], 0.01
    assert_in_delta 102.42, sum_q[1], 0.01
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/util/util-a.test.ts
class TestUtilA < Minitest::Test
  def setup
    @model = OpenSkill::Model.new
  end

  def test_util_a_basic
    r = @model.rating
    team_ratings = OpenSkill::Util.team_rating([[r], [r, r]])
    a = OpenSkill::Util.util_a(team_ratings)
    assert_equal [1, 1], a
  end

  def test_util_a_four_teams
    r = @model.rating
    team_ratings = OpenSkill::Util.team_rating([[r], [r, r], [r, r], [r]])
    a = OpenSkill::Util.util_a(team_ratings)
    assert_equal [1, 1, 1, 1], a
  end

  def test_util_a_with_ties
    r = @model.rating
    team_ratings = OpenSkill::Util.team_rating([[r], [r, r], [r, r], [r]], rank: [1, 1, 1, 4])
    a = OpenSkill::Util.util_a(team_ratings)
    assert_equal [3, 3, 3, 1], a
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/models/__tests__/plackett-luce.test.ts
class TestPlackettLuce < Minitest::Test
  def setup
    @model = OpenSkill::Model.new
  end

  def test_solo_game_unchanged
    r = @model.rating
    result = OpenSkill::PlackettLuce.rate([[r]], @model)
    assert_equal [[r]], result
  end

  def test_2p_ffa
    r = @model.rating
    result = OpenSkill::PlackettLuce.rate([[r], [r]], @model)
    assert_rating 27.63523138347365, 8.065506316323548, result[0][0]
    assert_rating 22.36476861652635, 8.065506316323548, result[1][0]
  end

  def test_3p_ffa
    r = @model.rating
    result = OpenSkill::PlackettLuce.rate([[r], [r], [r]], @model)
    assert_rating 27.868876552746237, 8.204837030780652, result[0][0]
    assert_rating 25.717219138186557, 8.057829747583874, result[1][0]
    assert_rating 21.413904309067206, 8.057829747583874, result[2][0]
  end

  def test_4p_ffa
    r = @model.rating
    result = OpenSkill::PlackettLuce.rate([[r], [r], [r], [r]], @model)
    assert_rating 27.795084971874736, 8.263160757613477, result[0][0]
    assert_rating 26.552824984374855, 8.179213704945203, result[1][0]
    assert_rating 24.68943500312503, 8.083731307186588, result[2][0]
    assert_rating 20.96265504062538, 8.083731307186588, result[3][0]
  end

  def test_5p_ffa
    r = @model.rating
    result = OpenSkill::PlackettLuce.rate([[r], [r], [r], [r], [r]], @model)
    assert_rating 27.666666666666668, 8.290556877154474, result[0][0]
    assert_rating 26.833333333333332, 8.240145629781066, result[1][0]
    assert_rating 25.72222222222222, 8.179996679645559, result[2][0]
    assert_rating 24.055555555555557, 8.111796013701358, result[3][0]
    assert_rating 20.72222222222222, 8.111796013701358, result[4][0]
  end

  def test_3_teams_different_sizes
    r = @model.rating
    result = OpenSkill::PlackettLuce.rate([[r, r, r], [r], [r, r]], @model)
    assert_rating 25.939870821784513, 8.247641552260456, result[0][0]
    assert_rating 25.939870821784513, 8.247641552260456, result[0][1]
    assert_rating 25.939870821784513, 8.247641552260456, result[0][2]
    assert_rating 27.21366020491262, 8.274321317985242, result[1][0]
    assert_rating 21.84646897330287, 8.213058173195341, result[2][0]
    assert_rating 21.84646897330287, 8.213058173195341, result[2][1]
  end

  private

  def assert_rating(expected_mu, expected_sigma, rating)
    assert_in_delta expected_mu, rating.mu, 1e-10, "mu mismatch"
    assert_in_delta expected_sigma, rating.sigma, 1e-10, "sigma mismatch"
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/__tests__/rate.test.ts
class TestRate < Minitest::Test
  def setup
    @model = OpenSkill::Model.new
  end

  def test_default_plackett_luce
    a1 = OpenSkill::Model.new(mu: 29.182, sigma: 4.782).rating
    b1 = OpenSkill::Model.new(mu: 27.174, sigma: 4.922).rating
    c1 = OpenSkill::Model.new(mu: 16.672, sigma: 6.217).rating
    d1 = @model.rating

    result = @model.rate([[a1], [b1], [c1], [d1]])
    assert_rating 30.209971908310553, 4.764898977359521, result[0][0]
    assert_rating 27.64460833689499, 4.882789305097372, result[1][0]
    assert_rating 17.403586731283518, 6.100723440599442, result[2][0]
    assert_rating 19.214790707434826, 7.8542613981643985, result[3][0]
  end

  def test_with_tau
    a1 = OpenSkill::Model.new(mu: 29.182, sigma: 4.782).rating
    b1 = OpenSkill::Model.new(mu: 27.174, sigma: 4.922).rating
    c1 = OpenSkill::Model.new(mu: 16.672, sigma: 6.217).rating
    d1 = @model.rating

    result = OpenSkill::Model.new(tau: 0.01).rate([[a1], [b1], [c1], [d1]])
    assert_rating 30.20997558824299, 4.764909330988368, result[0][0]
    assert_rating 27.64461002009721, 4.882799245921361, result[1][0]
    assert_rating 17.403587237635527, 6.100731158882956, result[2][0]
    assert_rating 19.21478808745494, 7.854267281042293, result[3][0]
  end

  def test_with_tau_and_prevent_sigma_increase
    a1 = OpenSkill::Model.new(mu: 6.672, sigma: 0.0001).rating
    b1 = OpenSkill::Model.new(mu: 29.182, sigma: 4.782).rating

    result = OpenSkill::Model.new(tau: 0.01, limit_sigma: true).rate([[a1], [b1]])
    assert_operator result[0][0].sigma, :<=, a1.sigma
    assert_rating 6.672012533190158, 0.0001, result[0][0]
    assert_rating 26.316243774876106, 4.7540633621019, result[1][0]
  end

  def test_reverses_rank
    r = @model.rating
    result = @model.rate([[r], [r]], rank: [2, 1])
    loser, winner = result[0][0], result[1][0]
    assert_rating 27.63523138347365, 8.065506316323548, winner
    assert_rating 22.36476861652635, 8.065506316323548, loser
  end

  def test_keeps_rank
    r = @model.rating
    result = @model.rate([[r], [r]], rank: [1, 2])
    loser, winner = result[0][0], result[1][0]
    assert_rating 22.36476861652635, 8.065506316323548, winner
    assert_rating 27.63523138347365, 8.065506316323548, loser
  end

  def test_misordered_rank
    d1 = @model.rating
    result = @model.rate([[d1], [d1], [d1], [d1]], rank: [2, 1, 4, 3])
    assert_rating 26.552824984374855, 8.179213704945203, result[0][0]
    assert_rating 27.795084971874736, 8.263160757613477, result[1][0]
    assert_rating 20.96265504062538, 8.083731307186588, result[2][0]
    assert_rating 24.68943500312503, 8.083731307186588, result[3][0]
  end

  def test_allows_ties
    a = OpenSkill::Model.new(mu: 10, sigma: 8).rating
    b = OpenSkill::Model.new(mu: 5, sigma: 10).rating
    c = OpenSkill::Model.new(mu: 0, sigma: 12).rating
    result = @model.rate([[a], [b], [c]], rank: [1, 2, 2])
    assert_rating 11.942833056030613, 7.926463661123746, result[0][0]
    assert_rating 2.938193791485662, 9.65347573412201, result[1][0]
    assert_rating(-1.4023734358082325, 11.323360667700934, result[2][0])
  end

  def test_four_way_tie_newbies
    r = @model.rating
    result = @model.rate([[r], [r], [r], [r]], rank: [1, 1, 1, 1])
    result.flatten.each do |rating|
      assert_rating 25, 8.263160757613477, rating
    end
  end

  def test_score_instead_of_rank
    e1 = @model.rating
    result = @model.rate([[e1], [e1], [e1]], score: [1, 1, 1])
    result.flatten.each do |rating|
      assert_rating 25, 8.204837030780652, rating
    end
  end

  def test_tau_term
    a = OpenSkill::Model.new(mu: 25, sigma: 3).rating
    b = OpenSkill::Model.new(mu: 25, sigma: 3).rating
    result = OpenSkill::Model.new(tau: 0.3).rate([[a], [b]])
    assert_rating 25.624880438870754, 2.9879993738476953, result[0][0]
    assert_rating 24.375119561129246, 2.9879993738476953, result[1][0]
  end

  def test_prevents_sigma_from_rising
    a = OpenSkill::Model.new(mu: 40, sigma: 3).rating
    b = OpenSkill::Model.new(mu: -20, sigma: 3).rating
    result = OpenSkill::Model.new(tau: 0.3, limit_sigma: true).rate([[a], [b]])
    assert_rating 40.00032667136128, 3, result[0][0]
    assert_rating(-20.000326671361275, 3, result[1][0])
  end

  def test_teams
    a1 = OpenSkill::Model.new(mu: 29.182, sigma: 4.782).rating
    b1 = OpenSkill::Model.new(mu: 27.174, sigma: 4.922).rating
    c1 = OpenSkill::Model.new(mu: 16.672, sigma: 6.217).rating
    d1 = @model.rating

    result = @model.rate([[a1, b1], [c1, d1]])
    assert_rating 29.607218266047376, 4.754597315295896, result[0][0]
    assert_rating 27.624480490655575, 4.89211428863373, result[0][1]
    assert_rating 15.953288649990139, 6.125357588584119, result[1][0]
    assert_rating 23.708690706816785, 8.111298027437888, result[1][1]
  end

  private

  def assert_rating(expected_mu, expected_sigma, rating)
    assert_in_delta expected_mu, rating.mu, 1e-10, "mu mismatch"
    assert_in_delta expected_sigma, rating.sigma, 1e-10, "sigma mismatch"
  end
end

# https://github.com/philihp/openskill.js/blob/main/src/models/__tests__/plackett-luce-series.test.ts
class TestPlackettLuceSeries < Minitest::Test
  def setup
    @model = OpenSkill::Model.new
  end

  def test_series
    p00 = @model.rating
    p10 = @model.rating
    p20 = @model.rating
    p30 = @model.rating
    p40 = @model.rating

    r1 = @model.rate([[p00], [p10], [p20], [p30], [p40]], score: [9, 7, 7, 5, 5])
    p01, p11, p21, p31, p41 = r1.map(&:first)

    p02 = p01
    p32 = p31

    r2 = @model.rate([[p41], [p21], [p11]], score: [9, 5, 5])
    p42, p22, p12 = r2.map(&:first)

    p43 = p42

    r3 = @model.rate([[p32], [p12], [p22], [p02]], score: [9, 9, 7, 7])
    p33, p13, p23, p03 = r3.map(&:first)

    assert_in_delta 26.353761103, p03.mu, 0.001
    assert_in_delta 8.11102706, p03.sigma, 0.001
    assert_in_delta 24.618479789, p13.mu, 0.001
    assert_in_delta 7.90533551, p13.sigma, 0.001
    assert_in_delta 23.065819512, p23.mu, 0.001
    assert_in_delta 7.822005595, p23.sigma, 0.001
    assert_in_delta 24.476332403, p33.mu, 0.001
    assert_in_delta 8.106111471, p33.sigma, 0.001
    assert_in_delta 26.385499685, p43.mu, 0.001
    assert_in_delta 8.054090809, p43.sigma, 0.001
  end
end
