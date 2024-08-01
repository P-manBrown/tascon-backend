module SetUserByTokenOverride
  extend ActiveSupport::Concern
  include DeviseTokenAuth::Concerns::SetUserByToken

  private
    # Override the set_cookie method defined in the devise_token_auth gem.
    # rubocop:disable Naming/AccessorMethodName
    def set_cookie(auth_header)
      expires = Time.zone.at(auth_header["expiry"].to_i)

      cookies[DeviseTokenAuth.cookie_name] = DeviseTokenAuth.cookie_attributes.merge(
        value: auth_header.to_json,
        expires:
      )

      cookies[:current_user_id] = DeviseTokenAuth.cookie_attributes.merge(
        value: current_api_v1_user.id,
        expires:
      )
    end
  # rubocop:enable Naming/AccessorMethodName
end
