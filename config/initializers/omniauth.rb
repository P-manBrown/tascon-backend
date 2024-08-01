Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter,
           Rails.application.credentials.twitter[:api_key],
           Rails.application.credentials.twitter[:api_key_secret]
  provider :google_oauth2,
           Rails.application.credentials.google[:client_id],
           Rails.application.credentials.google[:client_secret]
end

OmniAuth.config.request_validation_phase = proc do |env|
  OmniAuth::RailsCsrfProtection::TokenVerifier.new.call(env)
  raise ActionController::InvalidAuthenticityToken unless env["HTTP_ORIGIN"] == ENV.fetch("FRONTEND_ORIGIN")
end
