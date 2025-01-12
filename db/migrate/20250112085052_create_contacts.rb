class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.bigint :user_id, null: false
      t.bigint :contact_user_id, null: false

      t.timestamps
    end

    add_index :contacts, :user_id
    add_index :contacts, :contact_user_id
    add_index :contacts, %i[user_id contact_user_id], unique: true
  end
end
