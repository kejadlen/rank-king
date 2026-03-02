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

    def rate(teams, rank: nil, score: nil)
      processed_teams = teams

      # If tau is provided, use additive dynamics factor to keep ratings pliable
      if tau
        tau_sq = tau**2
        processed_teams = teams.map { |team|
          team.map { |p| Rating.new(p.mu, Math.sqrt(p.sigma**2 + tau_sq)) }
        }
      end

      # Build rank from score (negated so higher score = lower rank) or default 1..n
      rank = rank || score&.map { |s| -s } || (1..teams.length).to_a

      # Sort by rank, run the model, then restore original order
      ordered = processed_teams.zip(rank).sort_by(&:last)
      ordered_teams = ordered.map(&:first)
      sorted_rank = ordered.map(&:last)

      new_ratings = @rating_model.rate(ordered_teams, rank: sorted_rank)

      result = rank.zip(new_ratings).sort_by(&:first).map(&:last)

      # Cap sigma at pre-tau value so ordinal never drops after a win
      if tau && limit_sigma
        result = result.map.with_index { |team, i|
          team.map.with_index { |p, j|
            Rating.new(p.mu, [p.sigma, teams[i][j].sigma].min)
          }
        }
      end

      result
    end

    def ordinal(rating)
      target + alpha * (rating.mu - z * rating.sigma)
    end
  end
end
