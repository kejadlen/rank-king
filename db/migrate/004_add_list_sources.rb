# frozen_string_literal: true

Sequel.migration do
  up do
    # Every list gets its items from exactly one source. Lists before this
    # were made from the textarea, so they default to the text source. A
    # kind that needs configuring gets its own table keyed by list_id; text
    # needs none.
    alter_table(:lists) do
      add_column :source_kind, String, null: false, default: "text"
      add_column :synced_at, DateTime
    end

    alter_table(:items) do
      add_column :external_id, String
      add_column :url, String
      add_column :metadata, String, null: false, default: "{}"
      add_column :archived_at, DateTime
      add_index [:list_id, :external_id], unique: true
    end

    # A text item's external id is its name. Duplicate names keep a nil
    # external_id and are left alone by sync.
    first_ids = from(:items).group(:list_id, :name).select { min(:id) }
    from(:items).where(id: first_ids).update(external_id: :name)
  end

  down do
    alter_table(:items) do
      drop_index [:list_id, :external_id]
      drop_column :external_id
      drop_column :url
      drop_column :metadata
      drop_column :archived_at
    end

    alter_table(:lists) do
      drop_column :source_kind
      drop_column :synced_at
    end
  end
end
