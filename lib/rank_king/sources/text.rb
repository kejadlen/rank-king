# frozen_string_literal: true

module RankKing
  module Sources
    # A push source: the snapshot is pasted text, one item per line.
    class Text
      def self.kind = "text"
      def self.push? = true

      def initialize(config = {})
        @config = config
      end

      def entries(snapshot)
        snapshot.to_s.lines.map(&:strip).reject(&:empty?).uniq.map {|line|
          Entry.new(external_id: line, name: line)
        }
      end
    end
  end
end
