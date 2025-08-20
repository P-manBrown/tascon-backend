class RemoveIsBlockedIndexesFromContacts < ActiveRecord::Migration[8.0]
  def change
    remove_index :contacts, :is_blocked
    remove_index :contacts, [:user_id, :is_blocked]
  end
end
