class RemoveConstraintsFromUsersBio < ActiveRecord::Migration[8.0]
  def change
    change_column :users, :bio, :string, null: true, default: nil
  end
end
