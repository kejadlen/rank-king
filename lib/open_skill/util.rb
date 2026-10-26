# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/util.ts

module OpenSkill
  module Util
    #: (Integer q, Integer i) -> Float
    def self.score(q, i)
      case q <=> i
      when -1 then 0.0
      when  0 then 0.5
      else 1.0
      end
    end

    #: [T] (Array[T] ranks) -> Array[Array[T]]
    def self.ladder_pairs(ranks)
      return [[]] if ranks.length <= 1

      [nil, *ranks, nil].each_cons(3).map { |l, _, r| [l, r].compact }
    end

    #: (Array[TeamRating] team_ratings, Float beta_sq) -> Float
    def self.util_c(team_ratings, beta_sq)
      Math.sqrt(team_ratings.sum { |tr| tr.sigma_sq + beta_sq })
    end

    #: (Array[TeamRating] team_ratings, Float c) -> Array[Float]
    def self.util_sum_q(team_ratings, c)
      team_ratings.map { |qr|
        team_ratings
          .select { |ir| ir.rank >= qr.rank }
          .sum { |ir| Math.exp(ir.mu / c) }
      }
    end

    #: (Array[TeamRating] team_ratings) -> Array[Integer]
    def self.util_a(team_ratings)
      team_ratings.map { |ir| team_ratings.count { |qr| ir.rank == qr.rank } }
    end

    #: (number c, Integer _k, TeamRating tr) -> Float
    def self.gamma(c, _k, tr)
      Math.sqrt(tr.sigma_sq) / c
    end
  end
end
