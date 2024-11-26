module Api
  module V1
    module Auth
      class OmniauthCallbacksController < DeviseTokenAuth::OmniauthCallbacksController
        # TEMP: https://is.gd/keLG3H
        include ActionView::Layouts
        include ActionController::Rendering

        def omniauth_success
          super
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error(e)
          omniauth_failure
        end

        private
          def assign_provider_attrs(user, auth_hash)
            # Prevent user information from being overwritten during login.
            return unless @oauth_registration

            super
          end

          def render_data(message, data)
            @frontend_origin = ENV.fetch("FRONTEND_ORIGIN")
            @request_id = request.request_id

            if message == "deliverCredentials"
              update_auth_header
              data = data.merge(bearer_token: response.headers["Authorization"])
            end
            super
          end
      end
    end
  end
end
