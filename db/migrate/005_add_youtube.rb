# frozen_string_literal: true

Sequel.migration do
  change do
    # A user's connection to Google, for reading their YouTube playlists.
    # Only the refresh token is kept: each sync trades it for an access
    # token.
    create_table(:google_accounts) do
      primary_key :id
      foreign_key :user_id, :users, null: false, unique: true, on_delete: :cascade
      String :refresh_token, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end

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
