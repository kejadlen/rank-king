# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/rate.ts

module OpenSkill
  def self.rate(teams, **options)
    env = constants(**options)

    processed_teams = teams

    # If tau is provided, use additive dynamics factor to keep ratings pliable
    if options.key?(:tau)
      tau_sq = env.tau**2
      processed_teams = teams.map { |team|
        team.map { |p| Rating.new(p.mu, Math.sqrt(p.sigma**2 + tau_sq)) }
      }
    end

    # Build rank from score (negated so higher score = lower rank) or default 1..n
    rank = options[:rank] || options[:score]&.map { |s| -s } || (1..teams.length).to_a

    # Sort by rank, run the model, then restore original order
    ordered = processed_teams.zip(rank).sort_by(&:last)
    ordered_teams = ordered.map(&:first)
    sorted_rank = ordered.map(&:last)

    new_ratings = PlackettLuce.rate(ordered_teams, **options.merge(rank: sorted_rank))

    result = rank.zip(new_ratings).sort_by(&:first).map(&:last)

    # Cap sigma at pre-tau value so ordinal never drops after a win
    if options.key?(:tau) && env.limit_sigma
      result = result.map.with_index { |team, i|
        team.map.with_index { |p, j|
          Rating.new(p.mu, [p.sigma, teams[i][j].sigma].min)
        }
      }
    end

    result
  end
end
