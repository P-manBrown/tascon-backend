class UserResource < ApplicationResource
  root_key :user, :users

  attributes id: [String, true], name: [String, true], bio: [String, true], avatar_url: [String, true]
end
