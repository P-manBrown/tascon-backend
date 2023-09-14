class DeviseMailer < Devise::Mailer
  layout "mailer"

  def confirmation_instructions(record, token, opts = {})
    # Set redirect URL for email update.
    opts[:redirect_url] = record.redirect_url if record.is_a?(User) && record.redirect_url.present?

    super
  end
end
