class AddIsBlockedToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :is_blocked, :boolean, default: false, null: false
  end
end
