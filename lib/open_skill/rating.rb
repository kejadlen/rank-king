# frozen_string_literal: true

# Port of https://github.com/philihp/openskill.js/blob/main/src/rating.ts

module OpenSkill
  # Signed in sig/open_skill/rating.rbs: a Data class.
  # @rbs skip
  Rating = Data.define(:mu, :sigma)
end
