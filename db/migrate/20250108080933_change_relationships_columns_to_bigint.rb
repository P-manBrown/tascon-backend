class ChangeRelationshipsColumnsToBigint < ActiveRecord::Migration[7.2]
  def change
    change_column :relationships, :user_id, :bigint
    change_column :relationships, :associate_id, :bigint
  end
end
