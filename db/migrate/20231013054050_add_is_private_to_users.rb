class AddIsPrivateToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :is_private, :boolean
    change_column_default :users, :is_private, from: nil, to: true
    change_column_null :users, :is_private, false
  end
end
