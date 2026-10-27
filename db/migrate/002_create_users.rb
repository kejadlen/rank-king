# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :login, null: false, unique: true
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end

    # Lists created before users existed have no owner.
    alter_table(:lists) do
      add_foreign_key :user_id, :users
    end
  end
end
