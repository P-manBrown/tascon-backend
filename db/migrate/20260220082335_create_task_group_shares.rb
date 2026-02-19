class CreateTaskGroupShares < ActiveRecord::Migration[8.1]
  def change
    create_table :task_group_shares do |t|
      t.bigint :task_group_id, null: false
      t.bigint :user_id, null: false

      t.timestamps
    end

    add_index :task_group_shares, [:task_group_id, :user_id], unique: true
    add_index :task_group_shares, :user_id

    add_foreign_key :task_group_shares, :task_groups
    add_foreign_key :task_group_shares, :users
  end
end
