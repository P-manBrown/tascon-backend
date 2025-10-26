class TaskResource < ApplicationResource
  root_key :task, :tasks

  attributes :id, :name, :starts_at, :ends_at, :time_spent, :estimated_minutes, :note, :status

  one :task_group, resource: TaskGroupResource
end
