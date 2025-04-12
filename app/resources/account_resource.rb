class AccountResource < ApplicationResource
  root_key :account

  attributes :id, :name, :email, :is_private, :bio, :avatar_url, :provider
end
