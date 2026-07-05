class AddStatusToTaskGroupShares < ActiveRecord::Migration[8.1]
  def change
    add_column :task_group_shares, :status, :integer, null: false, default: 0
  end
end
