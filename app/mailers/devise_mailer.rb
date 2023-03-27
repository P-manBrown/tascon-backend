class DeviseMailer < Devise::Mailer
  layout "mailer"

  def confirmation_instructions(record, token, opts = {})
    # Set redirect URL for email update.
    if record.is_a?(User) && record.redirect_url.present?
      opts[:redirect_url] = record.redirect_url
    end

    super
  end
end
