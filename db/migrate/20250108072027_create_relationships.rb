class CreateRelationships < ActiveRecord::Migration[7.2]
  def change
    create_table :relationships do |t|
      t.integer :user_id
      t.integer :associate_id

      t.timestamps
    end
    add_index :relationships, :user_id
    add_index :relationships, :associate_id
    add_index :relationships, %i[user_id associate_id], unique: true
  end
end
