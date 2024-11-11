Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter,
           Rails.application.credentials.twitter[:api_key],
           Rails.application.credentials.twitter[:api_key_secret]
  provider :google_oauth2,
           Rails.application.credentials.google[:client_id],
           Rails.application.credentials.google[:client_secret]
end

class RequestValidator
  def call(env)
    dup._call(env)
  end

  def _call(env)
    request = ActionDispatch::Request.new(env.dup)

    return if request.origin == ENV.fetch("FRONTEND_ORIGIN")

    raise ActionController::BadRequest
  end

  private
    attr_reader :request
end

OmniAuth.config.request_validation_phase = RequestValidator.new
