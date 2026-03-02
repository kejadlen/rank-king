# frozen_string_literal: true

# Ruby port of https://github.com/philihp/openskill.js
# Implements the Plackett-Luce model for skill rating.

require_relative "open_skill/rating"
require_relative "open_skill/constants"
require_relative "open_skill/statistics"
require_relative "open_skill/util"
require_relative "open_skill/plackett_luce"
require_relative "open_skill/rate"
require_relative "open_skill/ordinal"

module OpenSkill
  def self.rating(**options)
    env = constants(**options)
    Rating.new(env[:mu], env[:sigma])
  end
end
