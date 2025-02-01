class ApplicationController < ActionController::API
  before_action :verify_request
  before_action :authenticate_api_v1_user!, unless: :devise_controller?
  # Avoid making the response headers too large.
  after_action :delete_user_session
  after_action :merge_pagy_headers, if: -> { @pagy.present? }

  include DeviseTokenAuth::Concerns::SetUserByToken
  include Pagy::Backend

  private
    def delete_user_session
      warden.session_serializer.delete("user")
    end

    def verify_request
      return if request.get? || request.head? || request.origin == ENV.fetch("FRONTEND_ORIGIN")

      raise ActionController::BadRequest
    end

    def merge_pagy_headers
      pagy_headers_merge(@pagy)
    end
end
