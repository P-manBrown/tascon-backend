Devise.setup do |config|
  require "devise/orm/active_record"
  config.mailer = "DeviseMailer"
  config.mailer_sender = "TASCON <#{Rails.application.credentials.gmail[:address]}>"
end
