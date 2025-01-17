class ContactResource < ApplicationResource
  root_key :contact, :contacts

  attributes id: [String, true]

  one :contact_user, resource: UserResource
end
