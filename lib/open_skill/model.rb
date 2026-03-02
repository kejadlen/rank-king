# frozen_string_literal: true

module OpenSkill
  class Model
    attr_reader :mu, :sigma, :beta, :beta_sq, :two_beta_sq,
                :epsilon, :z, :alpha, :target, :tau, :limit_sigma

    def initialize(mu: 25, z: 3, sigma: mu.to_f / z, beta: sigma / 2.0,
                   epsilon: 0.0001, alpha: 1, target: 0, tau: nil,
                   prevent_sigma_increase: false, limit_sigma: prevent_sigma_increase)
      @mu = mu
      @sigma = sigma
      @beta = beta
      @beta_sq = beta**2
      @two_beta_sq = 2 * @beta_sq
      @epsilon = epsilon
      @z = z
      @alpha = alpha
      @target = target
      @tau = tau
      @limit_sigma = limit_sigma

      @rating_model = PlackettLuce.new(self)
    end

    def rating
      Rating.new(mu, sigma)
    end

    # Rate teams grouped by placement. The structure has three levels because
    # the data is three-dimensional: placements contain teams, teams contain
    # players. Flattening any level loses information — either tie boundaries
    # or team boundaries. A 1v1 with solo players hits the worst case
    # (+[[[r]], [[r]]]+) where every level is a single-element array.
    #
    #   model.rate([[[winner]], [[loser]]])
    #   model.rate([[[first]], [[tied_a], [tied_b]], [[last]]])
    #
    # Returns a flat array of updated teams in the same (flattened) order.
    def rate(rank_groups)
      teams = rank_groups.flatten(1)
      rank = rank_groups.flat_map.with_index { |group, i| [i] * group.size }

      processed_teams = teams

      # If tau is provided, use additive dynamics factor to keep ratings pliable
      if tau
        tau_sq = tau**2
        processed_teams = teams.map { |team|
          team.map { |p| Rating.new(p.mu, Math.sqrt(p.sigma**2 + tau_sq)) }
        }
      end

      new_ratings = @rating_model.rate(processed_teams, rank: rank)

      # Cap sigma at pre-tau value so ordinal never drops after a win
      if tau && limit_sigma
        new_ratings = new_ratings.map.with_index { |team, i|
          team.map.with_index { |p, j|
            Rating.new(p.mu, [p.sigma, teams[i][j].sigma].min)
          }
        }
      end

      new_ratings
    end

    def ordinal(rating)
      target + alpha * (rating.mu - z * rating.sigma)
    end
  end
end
