class CreateTaskGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :task_groups do |t|
      t.bigint :user_id, null: false
      t.string :name, null: false
      t.string :icon, null: false
      t.text :note, limit: 1000

      t.timestamps
    end

    add_index :task_groups, :user_id

    add_foreign_key :task_groups, :users
  end
end
