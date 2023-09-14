Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter,
           Rails.application.credentials.twitter[:api_key],
           Rails.application.credentials.twitter[:api_key_secret]
  provider :google_oauth2,
           Rails.application.credentials.google[:client_id],
           Rails.application.credentials.google[:client_secret],
           skip_jwt: true

  OmniAuth.config.allowed_request_methods = %i[post]
end
