# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/models/plackett-luce.ts

module OpenSkill
  module PlackettLuce
    def self.rate(game, **options)
      return game if game.length <= 1

      env = OpenSkill.constants(**options)
      epsilon = env[:epsilon]

      team_ratings = Util.team_rating(game, **options)
      c = Util.util_c(team_ratings, **options)
      sum_q = Util.util_sum_q(team_ratings, c)
      a = Util.util_a(team_ratings)

      team_ratings.each_with_index.map do |i_team_rating, i|
        i_mu, i_sigma_sq, i_team, i_rank = i_team_rating
        i_mu_over_ce = Math.exp(i_mu / c)

        omega_sum = 0.0
        delta_sum = 0.0

        team_ratings.each_with_index do |q_team_rating, q|
          q_rank = q_team_rating[3]
          next unless q_rank <= i_rank

          quotient = i_mu_over_ce / sum_q[q]
          if i == q
            omega_sum += (1 - quotient) / a[q]
          else
            omega_sum += (-quotient) / a[q]
          end
          delta_sum += (quotient * (1 - quotient)) / a[q]
        end

        i_gamma = Util.gamma(c, team_ratings.length, *i_team_rating)
        i_omega = omega_sum * (i_sigma_sq / c)
        i_delta = i_gamma * delta_sum * (i_sigma_sq / c**2)

        i_team.map do |player|
          new_mu = player.mu + (player.sigma**2 / i_sigma_sq) * i_omega
          new_sigma = player.sigma * Math.sqrt([1 - (player.sigma**2 / i_sigma_sq) * i_delta, epsilon].max)
          Rating.new(new_mu, new_sigma)
        end
      end
    end
  end
end
