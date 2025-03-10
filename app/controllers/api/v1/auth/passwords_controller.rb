module Api
  module V1
    module Auth
      class PasswordsController < DeviseTokenAuth::PasswordsController
        def update
          super do |resource|
            # See https://is.gd/DNCnRT
            client = @token.client
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

          def resource_update_method
            # TEMP: https://is.gd/E52ElZ
            allow_password_change = recoverable_enabled? && @resource.allow_password_change == true
            if !check_current_password_before_update? || (allow_password_change && !params[:current_password])
              "update"
            else
              "update_with_password"
            end
          end

          def check_current_password_before_update?
            DeviseTokenAuth.check_current_password_before_update
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
            head :no_content
          end

          def render_update_success
            render json: AccountResource.new(@resource), status: :ok
          end

          def render_update_error
            render json: ErrorResource.new(@resource.errors), status: :unprocessable_entity
          end

          def resource_errors
            super
            @resource.errors.full_messages
          end
      end
    end
  end
end
