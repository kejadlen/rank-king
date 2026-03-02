# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/rating.ts

module OpenSkill
  Rating = Data.define(:mu, :sigma)

  # Intermediate structure for team-level aggregation during rating.
  # Produced by Util.team_rating, consumed by PlackettLuce and Util helpers.
  TeamRating = Data.define(:mu, :sigma_sq, :team, :rank) do
    def to_a = [mu, sigma_sq, team, rank]
  end
end
