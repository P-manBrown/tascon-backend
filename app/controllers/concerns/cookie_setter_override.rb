module CookieSetterOverride
  extend ActiveSupport::Concern
  include DeviseTokenAuth::Concerns::SetUserByToken

  # Overrides the set_cookie method defined in devise_token_auth gem.
  # rubocop:disable Naming/AccessorMethodName
  def set_cookie(auth_header)
    header_expiry = auth_header["expiry"]
    cookie_options = DeviseTokenAuth.cookie_attributes.merge(
      value: auth_header.to_json,
      expires: Time.zone.at(header_expiry.to_i)
    )
    cookies[DeviseTokenAuth.cookie_name] = cookie_options
  end
  # rubocop:enable Naming/AccessorMethodName
end
