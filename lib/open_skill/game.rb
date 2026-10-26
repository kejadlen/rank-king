# frozen_string_literal: true

module OpenSkill
  # A game result: placements (first to last), each containing one or more
  # tied teams, each containing one or more player Ratings.
  #
  #   Game.new([[winner]], [[loser]])
  #   Game.new([[first]], [[tied_a], [tied_b]], [[last]])
  #
  # Each argument is a placement group — an array of teams that tied at
  # that position. Each team is an array of Rating objects.

  # Intermediate structure for team-level aggregation during rating.
  # Produced by Game#team_ratings, consumed by PlackettLuce and Util helpers.
  # Signed in sig/open_skill/rating.rbs: a Data class.
  # @rbs skip
  TeamRating = Data.define(:mu, :sigma_sq, :team, :rank)

  # Reopened rather than defined in the block above, so the inline
  # parser reads its type.
  class TeamRating
    #: () -> [Float, Float, Array[Rating], Integer]
    def to_a = [mu, sigma_sq, team, rank]
  end

  class Game
    attr_reader :rank_groups #: Array[Array[Array[Rating]]]
    attr_reader :teams #: Array[Array[Rating]]
    attr_reader :rank #: Array[Integer]

    #: (*Array[Array[Rating]] rank_groups) -> void
    def initialize(*rank_groups)
      @rank_groups = rank_groups.freeze
      @teams = @rank_groups.flatten(1).freeze
      @rank = @rank_groups.flat_map.with_index { |group, i| [i] * group.size }.freeze
      freeze
    end

    #: (Array[Rating] winner, Array[Rating] loser) -> Game
    def self.win_lose(winner, loser)
      new([winner], [loser])
    end

    #: () -> Array[TeamRating]
    def team_ratings
      teams.zip(rankings).map { |team, rank|
        TeamRating.new(
          mu: team.sum(0.0) { |p| p.mu },
          sigma_sq: team.sum(0.0) { |p| p.sigma**2 },
          team: team,
          rank: rank, #: Integer
        )
      }
    end

    private

    # Dense ranks: tied teams share a rank, next group gets the next integer.
    # [0, 0, 1] not [0, 0, 2]. The Plackett-Luce math only uses relative
    # comparisons (<=, >=, ==) so dense and sparse ranks are equivalent.
    # The prior implementation produced sparse/positional ranks where gaps
    # reflect the number of tied teams ([0, 0, 2]). Restore that if a
    # future model needs it.
    #: () -> Array[Integer]
    def rankings
      rank.chunk_while { |a, b| a == b }.flat_map.with_index { |group, i|
        [i] * group.size
      }
    end
  end
end
