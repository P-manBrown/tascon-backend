class ErrorResource < ApplicationResource
  root_key :error, :errors

  attributes :attribute, :full_message

  typelize attribute: :string, full_message: :string
end
