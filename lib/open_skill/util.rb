# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/util.ts

module OpenSkill
  module Util
    # TeamRating: [mu, sigma_sq, team, rank]

    def self.score(q, i)
      if q < i
        0.0
      elsif q > i
        1.0
      else
        0.5
      end
    end

    def self.rankings(teams, rank)
      return [] if teams.empty?

      team_scores = teams.each_index.map { |i| rank && rank[i] ? rank[i] : i }
      out_rank = Array.new(teams.length)

      s = 0
      team_scores.each_with_index do |_score, j|
        s = j if j > 0 && team_scores[j - 1] < team_scores[j]
        out_rank[j] = s
      end
      out_rank
    end

    def self.ladder_pairs(ranks)
      size = ranks.length
      return [[]] if size <= 1

      left = [nil, *ranks[0...(size - 1)]]
      right = [*ranks[1..], nil]

      left.zip(right).map do |l, r|
        if l && r
          [l, r]
        elsif l
          [l]
        elsif r
          [r]
        else
          []
        end
      end
    end

    def self.team_rating(game, rank: nil, **_options)
      ranks = rankings(game, rank)
      game.each_with_index.map do |team, i|
        mu = team.sum(&:mu)
        sigma_sq = team.sum { |p| p.sigma**2 }
        [mu, sigma_sq, team, ranks[i]]
      end
    end

    def self.util_c(team_ratings, **options)
      beta_sq = OpenSkill.constants(**options)[:beta_sq]
      Math.sqrt(team_ratings.sum { |tr| tr[1] + beta_sq })
    end

    def self.util_sum_q(team_ratings, c)
      team_ratings.map do |q_rating|
        q_rank = q_rating[3]
        team_ratings
          .select { |i_rating| i_rating[3] >= q_rank }
          .sum { |i_rating| Math.exp(i_rating[0] / c) }
      end
    end

    def self.util_a(team_ratings)
      team_ratings.map do |i_rating|
        i_rank = i_rating[3]
        team_ratings.count { |q_rating| i_rank == q_rating[3] }
      end
    end

    def self.gamma(c, _k, _mu, sigma_sq, _team, _rank)
      Math.sqrt(sigma_sq) / c
    end
  end
end
