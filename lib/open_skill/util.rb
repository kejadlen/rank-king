# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/util.ts

module OpenSkill
  module Util
    def self.score(q, i)
      case q <=> i
      when -1 then 0.0
      when  0 then 0.5
      when  1 then 1.0
      end
    end

    def self.rankings(teams, rank)
      return [] if teams.empty?

      team_scores = teams.map.with_index { |_, i| rank&.at(i) || i }

      s = 0
      team_scores.map.with_index { |_, j|
        s = j if j > 0 && team_scores[j - 1] < team_scores[j]
        s
      }
    end

    def self.ladder_pairs(ranks)
      return [[]] if ranks.length <= 1

      [nil, *ranks, nil].each_cons(3).map { |l, _, r| [l, r].compact }
    end

    def self.team_rating(game, rank: nil)
      game.zip(rankings(game, rank)).map { |team, rank|
        TeamRating.new(
          mu: team.sum(&:mu),
          sigma_sq: team.sum { |p| p.sigma**2 },
          team: team,
          rank: rank,
        )
      }
    end

    def self.util_c(team_ratings, env)
      Math.sqrt(team_ratings.sum { |tr| tr.sigma_sq + env.beta_sq })
    end

    def self.util_sum_q(team_ratings, c)
      team_ratings.map { |qr|
        team_ratings
          .select { |ir| ir.rank >= qr.rank }
          .sum { |ir| Math.exp(ir.mu / c) }
      }
    end

    def self.util_a(team_ratings)
      team_ratings.map { |ir| team_ratings.count { |qr| ir.rank == qr.rank } }
    end

    def self.gamma(c, _k, tr)
      Math.sqrt(tr.sigma_sq) / c
    end
  end
end
