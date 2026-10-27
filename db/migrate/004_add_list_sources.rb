# frozen_string_literal: true

Sequel.migration do
  up do
    # Every list gets its items from exactly one source. Lists before this
    # were made from the textarea, so they default to the text source. A
    # kind that needs configuring gets its own table keyed by list_id; Text
    # needs none.
    alter_table(:lists) do
      add_column :source_kind, String, null: false, default: "Text"
      add_column :synced_at, DateTime
    end

    # Items keep only what any source has. How a kind recognizes its items
    # across syncs, and anything else it knows about them, lives in its own
    # table keyed by item_id; Text recognizes items by name.
    alter_table(:items) do
      add_column :url, String
      add_column :archived_at, DateTime
    end
  end

  down do
    alter_table(:items) do
      drop_column :url
      drop_column :archived_at
    end

    alter_table(:lists) do
      drop_column :source_kind
      drop_column :synced_at
    end
  end
end
