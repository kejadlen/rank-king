# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:lists) do
      primary_key :id
      String :name, null: false
      DateTime :created_at
      DateTime :updated_at
    end

    create_table(:items) do
      primary_key :id
      foreign_key :list_id, :lists, null: false
      String :name, null: false
      DateTime :created_at
      DateTime :updated_at
    end

    create_table(:axes) do
      primary_key :id
      foreign_key :list_id, :lists, null: false
      String :name, null: false
      DateTime :created_at
      DateTime :updated_at
    end

    create_table(:results) do
      primary_key :id
      foreign_key :axis_id, :axes, null: false
      foreign_key :winner_id, :items, null: false
      foreign_key :loser_id, :items, null: false
      DateTime :created_at
    end
  end
end
