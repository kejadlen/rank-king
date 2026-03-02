# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/constants.ts

module OpenSkill
  Env = Data.define(:mu, :sigma, :beta, :beta_sq, :two_beta_sq,
                    :epsilon, :z, :alpha, :target, :tau, :limit_sigma)

  def self.constants(**options)
    z = options.fetch(:z, 3)
    mu = options.fetch(:mu, 25)
    epsilon = options.fetch(:epsilon, 0.0001)
    alpha = options.fetch(:alpha, 1)
    target = options.fetch(:target, 0)
    prevent_sigma_increase = options.fetch(:prevent_sigma_increase, false)

    tau = options.fetch(:tau, mu / 300.0)
    sigma = options.fetch(:sigma, mu.to_f / z)
    beta = options.fetch(:beta, sigma / 2.0)
    limit_sigma = options.fetch(:limit_sigma, prevent_sigma_increase)

    beta_sq = beta**2

    Env.new(
      mu:, sigma:, beta:, beta_sq:,
      two_beta_sq: 2 * beta_sq,
      epsilon:, z:, alpha:, target:, tau:, limit_sigma:,
    )
  end
end
