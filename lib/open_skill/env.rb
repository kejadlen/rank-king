# frozen_string_literal: true

module OpenSkill
  Env = Data.define(:mu, :sigma, :beta, :beta_sq, :two_beta_sq,
                    :epsilon, :z, :alpha, :target, :tau, :limit_sigma)
end
