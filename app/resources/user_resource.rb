class UserResource < ApplicationResource
  root_key :user, :users

  attributes :id, :name, :bio, :avatar_url

  attribute :contact, if: proc { !params[:current_user_contact].nil? } do
    ContactResource.new(params[:current_user_contact], within: :user).to_h
  end

  attribute :block, if: proc { !params[:current_user_block].nil? } do
    BlockResource.new(params[:current_user_block], within: :user).to_h
  end

  attribute :is_suggested, if: proc { !params[:suggestion_user_ids].nil? } do |user|
    params[:suggestion_user_ids].include?(user.id)
  end
end
