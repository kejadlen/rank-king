# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/ordinal.ts

module OpenSkill
  def self.ordinal(rating, **options)
    env = constants(**options)
    env[:target] + env[:alpha] * (rating.mu - env[:z] * rating.sigma)
  end
end
