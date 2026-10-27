# frozen_string_literal: true

module RankKing
  module Sources
    # A push source: the snapshot is pasted text, one item per line.
    class Text
      #: () -> bool
      def self.push? = true

      # Text has no configuration, so every list's text source is the same.
      #: (List list) -> Text
      def self.for(list) = new

      #: (untyped snapshot) -> Array[Entry]
      def entries(snapshot)
        snapshot.to_s.lines.map(&:strip).reject(&:empty?).uniq.map {|line|
          Entry.new(external_id: line, name: line, url: nil, metadata: {})
        }
      end
    end
  end
end
