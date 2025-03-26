class ErrorResource < ApplicationResource
  root_key :error, :errors

  attributes :attribute, :type, :full_message
end
