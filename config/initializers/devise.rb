Devise.setup do |config|
  require "devise/orm/active_record"
  config.mailer = "DeviseMailer"
  config.mailer_sender = "TASCON <#{Rails.application.credentials.gmail[:address]}>"

  config.confirm_within = 1.day

  config.send_email_changed_notification = true
  config.send_password_change_notification = true
end
