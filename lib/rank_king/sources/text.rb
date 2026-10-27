# frozen_string_literal: true

module RankKing
  module Sources
    # A push source: the snapshot is pasted text, one item per line.
    class Text
      # @rbs @config: Hash[String, untyped]

      #: () -> String
      def self.kind = "text"

      #: () -> bool
      def self.push? = true

      #: (?Hash[String, untyped] config) -> void
      def initialize(config = {})
        @config = config
      end

      #: (untyped snapshot) -> Array[Entry]
      def entries(snapshot)
        snapshot.to_s.lines.map(&:strip).reject(&:empty?).uniq.map {|line|
          Entry.new(external_id: line, name: line, url: nil, metadata: {})
        }
      end
    end
  end
end
