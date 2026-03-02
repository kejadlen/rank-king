# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/constants.ts

module OpenSkill
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

    {
      sigma: sigma,
      mu: mu,
      epsilon: epsilon,
      two_beta_sq: 2 * beta_sq,
      beta: beta,
      beta_sq: beta_sq,
      z: z,
      alpha: alpha,
      target: target,
      tau: tau,
      limit_sigma: limit_sigma,
    }
  end
end
