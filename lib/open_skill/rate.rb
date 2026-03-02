# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/rate.ts

module OpenSkill
  def self.rate(teams, **options)
    env = constants(**options)

    processed_teams = teams

    # If tau is provided, use additive dynamics factor to keep ratings pliable
    if options.key?(:tau)
      tau_sq = env[:tau]**2
      processed_teams = teams.map do |team|
        team.map { |p| Rating.new(p.mu, Math.sqrt(p.sigma**2 + tau_sq)) }
      end
    end

    # Build rank from score (negated so higher score = lower rank) or default 1..n
    rank = options[:rank] || options[:score]&.map { |s| -s } || (1..teams.length).to_a

    # Sort by rank, run the model, then restore original order
    sort_order = rank.each_with_index.sort_by(&:first).map(&:last)
    ordered_teams = sort_order.map { |i| processed_teams[i] }
    sorted_rank = rank.sort

    new_ratings = PlackettLuce.rate(ordered_teams, **options.merge(rank: sorted_rank))

    result = Array.new(teams.length)
    sort_order.each_with_index { |orig, sorted| result[orig] = new_ratings[sorted] }

    # Cap sigma at pre-tau value so ordinal never drops after a win
    if options.key?(:tau) && env[:limit_sigma]
      result = result.each_with_index.map do |team, i|
        team.each_with_index.map do |p, j|
          Rating.new(p.mu, [p.sigma, teams[i][j].sigma].min)
        end
      end
    end

    result
  end
end
