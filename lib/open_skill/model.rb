# frozen_string_literal: true

module OpenSkill
  class Model
    attr_reader :env

    def initialize(**options)
      z = options.fetch(:z, 3)
      mu = options.fetch(:mu, 25)
      epsilon = options.fetch(:epsilon, 0.0001)
      alpha = options.fetch(:alpha, 1)
      target = options.fetch(:target, 0)
      prevent_sigma_increase = options.fetch(:prevent_sigma_increase, false)

      tau = options[:tau]
      sigma = options.fetch(:sigma, mu.to_f / z)
      beta = options.fetch(:beta, sigma / 2.0)
      limit_sigma = options.fetch(:limit_sigma, prevent_sigma_increase)

      beta_sq = beta**2

      @env = Env.new(
        mu:, sigma:, beta:, beta_sq:,
        two_beta_sq: 2 * beta_sq,
        epsilon:, z:, alpha:, target:, tau:, limit_sigma:,
      )
    end

    def rating
      Rating.new(env.mu, env.sigma)
    end

    def rate(teams, rank: nil, score: nil)
      processed_teams = teams

      # If tau is provided, use additive dynamics factor to keep ratings pliable
      if env.tau
        tau_sq = env.tau**2
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

      new_ratings = PlackettLuce.rate(ordered_teams, env, rank: sorted_rank)

      result = rank.zip(new_ratings).sort_by(&:first).map(&:last)

      # Cap sigma at pre-tau value so ordinal never drops after a win
      if env.tau && env.limit_sigma
        result = result.map.with_index { |team, i|
          team.map.with_index { |p, j|
            Rating.new(p.mu, [p.sigma, teams[i][j].sigma].min)
          }
        }
      end

      result
    end

    def ordinal(rating)
      env.target + env.alpha * (rating.mu - env.z * rating.sigma)
    end
  end
end
