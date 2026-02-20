class TaskGroupShareResource < ApplicationResource
  root_key :task_group_share, :task_group_shares

  attributes :id

  attribute :task_group do |task_group_share|
    TaskGroupResource.new(task_group_share.task_group).to_h.merge(
      owner: UserResource.new(task_group_share.task_group.user).to_h
    )
  end
end
