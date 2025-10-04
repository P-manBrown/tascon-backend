class TaskGroupResource < ApplicationResource
  root_key :task_group, :task_groups

  attributes :id, :name, :icon, :note
end
