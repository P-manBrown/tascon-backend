class ApplicationController < ActionController::API
  include ActionController::Cookies
  include CookieSetterOverride
end
