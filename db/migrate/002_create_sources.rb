# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:sources) do
      primary_key :id
      foreign_key :list_id, :lists, null: false
      String :kind, null: false
      String :config, null: false, default: "{}"
      DateTime :last_synced_at
      DateTime :created_at
      DateTime :updated_at
    end

    alter_table(:items) do
      add_foreign_key :source_id, :sources
      add_column :external_id, String
      add_column :url, String
      add_column :metadata, String, null: false, default: "{}"
      add_column :archived_at, DateTime
      add_index [:source_id, :external_id], unique: true
    end

    # Existing lists were created from the textarea, so give each one a text
    # source. Duplicate names keep a nil external_id and are left alone by sync.
    from(:lists).each do |list|
      source_id = from(:sources).insert(
        list_id: list[:id], kind: "text", config: "{}",
        created_at: Time.now, updated_at: Time.now,
      )
      from(:items).where(list_id: list[:id]).update(source_id: source_id)

      first_ids = from(:items).where(list_id: list[:id]).group(:name).select { min(:id) }
      from(:items).where(id: first_ids).update(external_id: :name)
    end
  end

  down do
    alter_table(:items) do
      drop_index [:source_id, :external_id]
      drop_foreign_key :source_id
      drop_column :external_id
      drop_column :url
      drop_column :metadata
      drop_column :archived_at
    end

    drop_table(:sources)
  end
end
