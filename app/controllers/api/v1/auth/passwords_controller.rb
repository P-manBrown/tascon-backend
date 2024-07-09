module Api
  module V1
    module Auth
      class PasswordsController < DeviseTokenAuth::PasswordsController
        def update
          super do |resource|
            client = JSON.parse(cookies[DeviseTokenAuth.cookie_name])["client"]
            resource.remove_tokens_after_password_reset(client)
            resource.save!
          end
        end

        private
          def provider_name
            providers = {
              "google_oauth2" => "Google",
              "twitter" => "X"
            }
            providers[@resource.provider]
          end

          def render_update_error_password_not_required
            render_error(
              422,
              I18n.t(
                "devise_token_auth.passwords.password_not_required",
                provider: provider_name
              )
            )
          end

          def render_create_success
            render json: {
              success: true,
              email: @email,
              message: success_message("passwords", @email)
            }
          end

          def resource_errors
            super
            @resource.errors.full_messages
          end
      end
    end
  end
end
