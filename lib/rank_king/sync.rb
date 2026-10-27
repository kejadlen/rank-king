# frozen_string_literal: true

require_relative "models"

module RankKing
  # Reconciles a list's items with a fresh snapshot of entries from its
  # source. Items missing from the snapshot are archived rather than deleted
  # so their results survive, and come back with their history if they
  # reappear.
  module Sync
    # Signed in sig/rank_king/sync.rbs: a Data class.
    # @rbs skip
    Summary = Data.define(:added, :restored, :archived)

    #: (List list, Array[Sources::Entry] entries, ?now: Time) -> Summary
    def self.call(list, entries, now: Time.now)
      DB.transaction do
        existing = Item.where(list_id: list.id).exclude(external_id: nil).to_hash(:external_id)
        added = restored = 0

        entries.each do |entry|
          attrs = { name: entry.name, url: entry.url, metadata: entry.metadata, archived_at: nil }
          if (item = existing.delete(entry.external_id))
            restored += 1 if item.archived_at
            item.update(**attrs)
          else
            Item.create(**attrs, list_id: list.id, external_id: entry.external_id)
            added += 1
          end
        end

        gone = existing.values.select {|item| item.archived_at.nil? }
        gone.each {|item| item.update(archived_at: now) }

        list.update(synced_at: now)
        Summary.new(added:, restored:, archived: gone.size)
      end
    end
  end
end
