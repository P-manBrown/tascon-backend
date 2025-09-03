class BlockResource < ApplicationResource
  root_key :block, :blocks

  attributes :id

  one :blocked, resource: UserResource
end
