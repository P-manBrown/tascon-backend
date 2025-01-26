class UserResource < ApplicationResource
  root_key :user, :users

  attributes :id, :name, :bio, :avatar_url

  attribute :current_user_contact, if: proc { !params[:current_user_contact].nil? } do
    ContactResource.new(params[:current_user_contact], within: :user).to_h
  end
end
