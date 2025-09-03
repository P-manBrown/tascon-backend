class RemoveBlockedAtFromContacts < ActiveRecord::Migration[8.0]
  def change
    remove_column :contacts, :blocked_at, :timestamp
  end
end
