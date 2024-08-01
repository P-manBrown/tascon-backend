module UserOverride
  extend ActiveSupport::Concern
  include DeviseTokenAuth::Concerns::User

  # Override https://tinyurl.com/2detqylw

  def self.included(base)
    base.skip_callback :save, :before, :remove_tokens_after_password_reset
  end

  def remove_tokens_after_password_reset(client)
    return unless should_remove_tokens_after_password_reset?

    return unless tokens.present? && tokens.many?

    self.tokens = { client => tokens[client] }
  end

  private
    def should_remove_tokens_after_password_reset?
      DeviseTokenAuth.remove_tokens_after_password_reset
    end
end
