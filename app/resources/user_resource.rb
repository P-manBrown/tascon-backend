class UserResource < ApplicationResource
  root_key :user, :users

  attributes :id, :name, :bio, :avatar_url

  typelize avatar_url: [:string, { nullable: true }]
end
