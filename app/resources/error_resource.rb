class ErrorResource < ApplicationResource
  root_key :error, :errors

  attributes attribute: [String, true], full_message: [String, true]
end
