# frozen_string_literal: true

require_relative "models"

module RankKing
  # Reconciles a source's items with a fresh snapshot of entries. Items missing
  # from the snapshot are archived rather than deleted so their results survive,
  # and come back with their history if they reappear.
  module Sync
    Summary = Data.define(:added, :restored, :archived)

    def self.call(source, entries, now: Time.now)
      DB.transaction do
        existing = source.items_dataset.exclude(external_id: nil).to_hash(:external_id)
        added = restored = 0

        entries.each do |entry|
          attrs = { name: entry.name, url: entry.url, metadata: entry.metadata, archived_at: nil }
          if (item = existing.delete(entry.external_id))
            restored += 1 if item.archived_at
            item.update(attrs)
          else
            Item.create(attrs.merge(list_id: source.list_id, source_id: source.id, external_id: entry.external_id))
            added += 1
          end
        end

        gone = existing.values.select {|item| item.archived_at.nil? }
        gone.each {|item| item.update(archived_at: now) }

        source.update(last_synced_at: now)
        Summary.new(added:, restored:, archived: gone.size)
      end
    end
  end
end
