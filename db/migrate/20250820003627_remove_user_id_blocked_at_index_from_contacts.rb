class RemoveUserIdBlockedAtIndexFromContacts < ActiveRecord::Migration[8.0]
  def change
    remove_index :contacts, [:user_id, :blocked_at]
  end
end
