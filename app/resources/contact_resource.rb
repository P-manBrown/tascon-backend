class ContactResource < ApplicationResource
  root_key :contact, :contacts

  attributes :id, :display_name, :note

  attribute :is_blocked do |contact|
    contact.blocked_at.present?
  end

  one :contact_user, resource: UserResource
end
