DeviseTokenAuth.setup do |config|
  config.change_headers_on_each_request = false

  config.cookie_enabled = true
  config.cookie_attributes = {
    http_only: true,
    secure: Rails.env.production?,
    same_site: Rails.env.production? ? "None" : "Lax"
  }

  config.token_cost = Rails.env.test? ? 4 : 10

  config.send_confirmation_email = true

  config.redirect_whitelist = ["#{ENV.fetch('FRONTEND_ORIGIN')}/*"]

  config.check_current_password_before_update = :password

  config.remove_tokens_after_password_reset = true

  config.omniauth_prefix = "/api/v1/omniauth"
end

Rails.application.config.to_prepare do
  DeviseTokenAuth::ApplicationController.class_eval do
    def redirect_options
      { allow_other_host: true }
    end
  end
end
