# frozen_string_literal: true

# Lists from before users existed go to the first user, the one who signed in
# when the user migration was first deployed, and every list has an owner
# from here on. Run it only after that first sign-in: with no users yet, it
# fails rather than leave lists without one.
Sequel.migration do
  up do
    unowned = from(:lists).where(user_id: nil)
    unless unowned.empty?
      first_user = from(:users).min(:id)
      raise "no users to own the #{unowned.count} lists without an owner" unless first_user

      unowned.update(user_id: first_user)
    end

    alter_table(:lists) do
      set_column_not_null :user_id
    end
  end

  down do
    alter_table(:lists) do
      set_column_allow_null :user_id
    end
  end
end
