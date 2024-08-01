class AddBioToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :bio, :string
    change_column_default :users, :bio, from: nil, to: ""
    change_column_null :users, :bio, false
  end
end
