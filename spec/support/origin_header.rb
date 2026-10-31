module OriginHeader
  # ApplicationController#verify_request rejects non-GET requests from any other origin.
  def origin_header
    { "Origin" => ENV.fetch("FRONTEND_ORIGIN") }
  end
end

RSpec.configure do |config|
  config.include OriginHeader, type: :request
end
