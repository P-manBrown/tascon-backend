class ContactResource < ApplicationResource
  root_key :contact, :contacts

  attributes :id, :display_name, :note

  one :contact_user, resource: UserResource
end
