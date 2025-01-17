class AddForeignKeyToContacts < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :contacts, :users, column: :user_id
    add_foreign_key :contacts, :users, column: :contact_user_id
  end
end
