# frozen_string_literal: true

require_relative "models"

module RankKing
  # Reconciles a list's items with a fresh snapshot of entries from its
  # source. Items missing from the snapshot are archived rather than deleted
  # so their results survive, and come back with their history if they
  # reappear. A kind that fetches its items calls this from its own sync.
  module Sync
    # Signed in sig/rank_king/sync.rbs: a Data class.
    # @rbs skip
    Summary = Data.define(:added, :restored, :archived)

    #: (List list, Array[Sources::Entry] entries, source: Sources::_Synced, ?now: Time) -> Summary
    def self.call(list, entries, source:, now: Time.now)
      DB.transaction do
        existing = source.items_by_key
        added = restored = 0

        entries.each do |entry|
          attrs = { name: entry.name, archived_at: nil }
          if (item = existing.delete(entry.key))
            restored += 1 if item.archived_at
            item.update(**attrs)
          else
            item = Item.create(**attrs, list_id: list.id)
            added += 1
          end
          source.saved(item, entry)
        end

        gone = existing.values.select {|item| item.archived_at.nil? }
        gone.each {|item| item.update(archived_at: now) }

        list.update(synced_at: now)
        Summary.new(added:, restored:, archived: gone.size)
      end
    end
  end
end
