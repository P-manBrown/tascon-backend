class TaskGroupResource < ApplicationResource
  root_key :task_group, :task_groups

  attributes :id, :name, :icon, :note

  many :shared_users, resource: UserResource, if: proc { params[:include_shared_users] }
end
