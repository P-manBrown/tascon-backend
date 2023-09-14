# TEMP: https://github.com/heartcombo/devise/issues/5443
require "devise_token_auth/version"
raise "Consider removing this patch." unless DeviseTokenAuth::VERSION == "1.2.2"

Rails.configuration.to_prepare do
  DeviseTokenAuth::ApplicationController.class_eval do
    rescue_from ActionController::Redirecting::UnsafeRedirectError, with: :redirect_judgment

    def redirect_judgment
      redirect_url ||= params[:redirect_url]
      if !blacklisted_redirect_url?(redirect_url) && DeviseTokenAuth.redirect_whitelist
        return redirect_to(redirect_url, allow_other_host: true)
      end

      raise ActionController::Redirecting::UnsafeRedirectError,
            "Unsafe redirect to \"#{redirect_url}\", add the URL to DeviseTokenAuth.redirect_whitelist to redirect."
    end
  end
end
