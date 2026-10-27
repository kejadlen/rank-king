# frozen_string_literal: true

module RankKing
  module Sources
    # A manual source: items are added and removed by hand on the list page,
    # each by its own id, so there is nothing to sync.
    class Text
      #: () -> bool
      def self.manual? = true
    end
  end
end
