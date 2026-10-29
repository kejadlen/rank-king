# frozen_string_literal: true

Sequel.migration do
  change do
    # The YouTube source's config: which playlist a list follows.
    create_table(:youtube_sources) do
      foreign_key :list_id, :lists, primary_key: true, on_delete: :cascade
      String :playlist_id, null: false
    end

    # The video behind each item of a YouTube list, which is how
    # a sync recognizes the item again, and what YouTube said about it at
    # the last sync.
    create_table(:youtube_items) do
      foreign_key :item_id, :items, primary_key: true, on_delete: :cascade
      String :video_id, null: false
      String :title, null: false
      String :channel_title
      String :thumbnail_url
    end
  end
end
