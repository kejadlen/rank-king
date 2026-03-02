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
  class Game
    attr_reader :rank_groups, :teams, :rank

    def initialize(*rank_groups)
      @rank_groups = rank_groups.freeze
      @teams = @rank_groups.flatten(1).freeze
      @rank = @rank_groups.flat_map.with_index { |group, i| [i] * group.size }.freeze
      freeze
    end

    def self.win_lose(winner, loser)
      new([winner], [loser])
    end

    def team_ratings
      teams.zip(rankings).map { |team, rank|
        TeamRating.new(
          mu: team.sum(&:mu),
          sigma_sq: team.sum { |p| p.sigma**2 },
          team: team,
          rank: rank,
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
    def rankings
      rank.chunk_while { |a, b| a == b }.flat_map.with_index { |group, i|
        [i] * group.size
      }
    end
  end
end
