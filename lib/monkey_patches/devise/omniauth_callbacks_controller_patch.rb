# TEMP: Occasionally, Devise's failure action may be triggered when omniauth fails.
#      e.g. when the CSRF token is invalid.

require "devise/version"
require "devise_token_auth/version"
raise "Consider removing this patch." unless Devise::VERSION == "4.9.4"
raise "Consider removing this patch." unless DeviseTokenAuth::VERSION == "1.2.6"

Rails.application.config.to_prepare do
  Devise::OmniauthCallbacksController.class_eval do
    rescue_from ActionController::BadRequest, with: :failure

    def failure
      redirect_to controller: "api/v1/auth/omniauth_callbacks",
                  action: "omniauth_failure",
                  omniauth_window_type: params["omniauth_window_type"] || "newWindow",
                  message: "処理中にエラーが発生しました。"
    end
  end
end
