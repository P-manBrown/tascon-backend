class CreateBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :blocks do |t|
      t.bigint :blocker_id, null: false
      t.bigint :blocked_id, null: false

      t.timestamps
    end


    add_index :blocks, :blocked_id
    add_index :blocks, %i[blocker_id blocked_id], unique: true


    add_foreign_key :blocks, :users, column: :blocker_id
    add_foreign_key :blocks, :users, column: :blocked_id
  end
end
