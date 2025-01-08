class AddNotNullToRelationships < ActiveRecord::Migration[7.2]
  def change
    change_column_null :relationships, :user_id, false
    change_column_null :relationships, :associate_id, false
  end
end
