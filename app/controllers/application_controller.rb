class ApplicationController < ActionController::API
  before_action :authenticate_api_v1_user!, unless: :devise_controller?
  # Avoid making the response headers too large.
  after_action :delete_user_session
  after_action :delete_csrf_token, only: :destroy, if: :devise_controller?
  after_action :delete_current_user_id, only: :destroy, if: :devise_controller?

  include ActionController::Cookies
  include ActionController::RequestForgeryProtection
  include SetUserByTokenOverride

  protect_from_forgery with: :exception

  private
    def delete_user_session
      warden.session_serializer.delete("user")
    end

    def delete_csrf_token
      session.delete(:_csrf_token)
      cookies.delete(:csrf_token)
    end

    def delete_current_user_id
      cookies.delete(:current_user_id)
    end

    def render_error(status, message)
      response = {
        errors: [message]
      }
      render json: response, status:
    end

    # Override http://tinyurl.com/23fhrj2t
    def valid_request_origin?
      forgery_protection_origin_check = true # rubocop:disable Lint/UselessAssignment
      super || request.origin == ENV.fetch("FRONTEND_ORIGIN")
    end

    # Override http://tinyurl.com/2xnc2l8e
    def unverified_request_warning_message
      if valid_request_origin?
        ""
      else
        "HTTP Origin header (#{request.origin}) didn't match FRONTEND_ORIGIN (#{ENV.fetch('FRONTEND_ORIGIN')})"
      end
    end
end
