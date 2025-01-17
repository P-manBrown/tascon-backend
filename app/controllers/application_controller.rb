class ApplicationController < ActionController::API
  before_action :verify_request
  before_action :authenticate_api_v1_user!, unless: :devise_controller?
  # Avoid making the response headers too large.
  after_action :delete_user_session

  include DeviseTokenAuth::Concerns::SetUserByToken

  private
    def delete_user_session
      warden.session_serializer.delete("user")
    end

    def verify_request
      return if request.get? || request.head? || request.origin == ENV.fetch("FRONTEND_ORIGIN")

      raise ActionController::BadRequest
    end
end
