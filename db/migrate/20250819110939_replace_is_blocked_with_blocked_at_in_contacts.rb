class ReplaceIsBlockedWithBlockedAtInContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :blocked_at, :timestamp, null: true
    remove_column :contacts, :is_blocked, :boolean
    add_index :contacts, [:user_id, :blocked_at]
  end
end
