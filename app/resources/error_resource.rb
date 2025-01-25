class ErrorResource < ApplicationResource
  root_key :error, :errors

  attributes :attribute, :full_message
end
