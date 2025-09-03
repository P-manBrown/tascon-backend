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

    def render_custom_error(attribute:, type:, message:, status: :unprocessable_entity)
      error = {
        attribute: attribute,
        type: type,
        full_message: message
      }
      render json: ErrorResource.new(error), status: status
    end

    def render_validation_error(errors)
      render json: ErrorResource.new(errors), status: :unprocessable_entity
    end

    def set_user
      @user = User.find(params[:user_id])
    end

    def authorize_user_access
      return if @user == current_api_v1_user

      head :forbidden
    end
end
