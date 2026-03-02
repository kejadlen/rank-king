# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/rate.ts

module OpenSkill
  def self.rate(teams, **options)
    env = constants(**options)
    limit_sigma = env[:limit_sigma]
    tau = env[:tau]

    processed_teams = teams

    # If tau is provided, use additive dynamics factor
    if options.key?(:tau)
      tau_squared = tau**2
      processed_teams = teams.map do |team|
        team.map do |p|
          Rating.new(p.mu, Math.sqrt(p.sigma**2 + tau_squared))
        end
      end
    end

    # Build rank from score or use provided rank, or default 1..n
    rank = options[:rank] || options[:score]&.map { |s| -s } || (1..teams.length).to_a

    # Sort teams by rank, process, then unsort
    tenet = rank.each_with_index.sort_by { |r, _| r }.map(&:last)
    ordered_teams = tenet.map { |i| processed_teams[i] }
    sorted_rank = rank.sort

    new_ratings = PlackettLuce.rate(ordered_teams, **options.merge(rank: sorted_rank))

    # Unsort back to original order
    reordered = Array.new(teams.length)
    tenet.each_with_index { |orig_idx, sorted_idx| reordered[orig_idx] = new_ratings[sorted_idx] }

    # Limit sigma if requested
    if options.key?(:tau) && limit_sigma
      reordered = reordered.each_with_index.map do |team, i|
        team.each_with_index.map do |p, j|
          Rating.new(p.mu, [p.sigma, teams[i][j].sigma].min)
        end
      end
    end

    reordered
  end
end
