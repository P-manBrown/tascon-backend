# TEMP: The set_cookie method is not used in the set_token_in_cookie method to set the auth_cookie.
#      see http://tinyurl.com/yla25xhq

require "devise_token_auth/version"
raise "Consider removing this patch." unless DeviseTokenAuth::VERSION == "1.2.4"

Rails.application.config.to_prepare do
  DeviseTokenAuth::ApplicationController.class_eval do
    def set_token_in_cookie(resource, token)
      auth_header = resource.build_auth_headers(token.token, token.client)
      set_cookie(auth_header)
    end
  end
end
