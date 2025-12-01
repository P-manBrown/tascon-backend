class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.bigint :task_group_id, null: false
      t.string :name, null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :time_spent
      t.integer :estimated_minutes
      t.text :note, limit: 1000
      t.boolean :is_completed, null: false, default: false

      t.timestamps
    end

    add_index :tasks, :task_group_id
    add_foreign_key :tasks, :task_groups
  end
end
