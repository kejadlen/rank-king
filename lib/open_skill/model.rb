# frozen_string_literal: true

module OpenSkill
  class Model
    attr_reader :mu, :sigma, :beta, :beta_sq, :two_beta_sq, :epsilon, :z, :alpha, :target #: Float
    attr_reader :tau #: Float?
    attr_reader :limit_sigma #: bool

    # Parameters are taken as written, 25 or 8.33, and kept as Floats.
    #
    # @rbs mu: number
    # @rbs z: number
    # @rbs sigma: number
    # @rbs beta: number
    # @rbs epsilon: number
    # @rbs alpha: number
    # @rbs target: number
    # @rbs tau: number?
    # @rbs prevent_sigma_increase: bool
    # @rbs limit_sigma: bool
    # @rbs return: void
    def initialize(mu: 25, z: 3, sigma: mu.to_f / z, beta: sigma.to_f / 2,
                   epsilon: 0.0001, alpha: 1, target: 0, tau: nil,
                   prevent_sigma_increase: false, limit_sigma: prevent_sigma_increase)
      @mu = mu.to_f
      @sigma = sigma.to_f
      @beta = beta.to_f
      @beta_sq = @beta**2
      @two_beta_sq = 2 * @beta_sq
      @epsilon = epsilon.to_f
      @z = z.to_f
      @alpha = alpha.to_f
      @target = target.to_f
      @tau = tau&.to_f
      @limit_sigma = limit_sigma

      @rating_model = PlackettLuce.new(self)
    end

    #: () -> Rating
    def rating
      Rating.new(mu, sigma)
    end

    # Rate teams given a Game — placements (first to last), each containing
    # one or more tied teams, each containing player Ratings.
    #
    #   model.rate(Game.new([[winner]], [[loser]]))
    #   model.rate(Game.new([[first]], [[tied_a], [tied_b]], [[last]]))
    #
    # Returns a flat array of updated teams in the same (flattened) order.
    #: (Game game) -> Array[Array[Rating]]
    def rate(game)
      processed_game = game
      tau = self.tau

      # If tau is provided, use additive dynamics factor to keep ratings pliable
      if tau
        tau_sq = tau**2
        inflated_groups = game.rank_groups.map { |group|
          group.map { |team|
            team.map { |p| Rating.new(p.mu, Math.sqrt(p.sigma**2 + tau_sq)) }
          }
        }
        processed_game = Game.new(*inflated_groups)
      end

      new_ratings = @rating_model.rate(processed_game)

      # Cap sigma at pre-tau value so ordinal never drops after a win
      if tau && limit_sigma
        new_ratings = new_ratings.map.with_index { |team, i|
          team.map.with_index { |p, j|
            Rating.new(p.mu, [p.sigma, game.teams[i][j].sigma].min)
          }
        }
      end

      new_ratings
    end

    #: (Rating rating) -> Float
    def ordinal(rating)
      target + alpha * (rating.mu - z * rating.sigma)
    end
  end
end
