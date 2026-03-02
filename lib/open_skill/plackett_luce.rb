# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/models/plackett-luce.ts

module OpenSkill
  module PlackettLuce
    def self.rate(game, env, rank: nil)
      return game if game.length <= 1

      team_ratings = Util.team_rating(game, rank: rank)
      c = Util.util_c(team_ratings, env.beta_sq)
      sum_q = Util.util_sum_q(team_ratings, c)
      a = Util.util_a(team_ratings)

      team_ratings.map.with_index { |tr, i|
        mu_over_ce = Math.exp(tr.mu / c)

        omega_sum = 0.0
        delta_sum = 0.0

        team_ratings.each.with_index
          .select {|qr, _| qr.rank <= tr.rank }
          .each do |_, q|
            quotient = mu_over_ce / sum_q[q]
            omega_sum += ((i == q ? 1 : 0) - quotient) / a[q]
            delta_sum += (quotient * (1 - quotient)) / a[q]
          end

        g = Util.gamma(c, team_ratings.length, tr)
        omega = omega_sum * (tr.sigma_sq / c)
        delta = g * delta_sum * (tr.sigma_sq / c**2)

        tr.team.map { |player|
          share = player.sigma**2 / tr.sigma_sq
          new_mu = player.mu + share * omega
          new_sigma = player.sigma * Math.sqrt([1 - share * delta, env.epsilon].max)
          Rating.new(new_mu, new_sigma)
        }
      }
    end
  end
end
