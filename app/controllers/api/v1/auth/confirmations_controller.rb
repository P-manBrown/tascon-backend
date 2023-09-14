module Api
  module V1
    module Auth
      class ConfirmationsController < DeviseTokenAuth::ConfirmationsController
        def create
          return render_create_error_missing_redirect_url if confirmable_enabled? && !redirect_url
          return render_error_not_allowed_redirect_url if blacklisted_redirect_url?(redirect_url)

          super
        end

        private
          def render_create_error_missing_redirect_url
            render_error(
              401,
              I18n.t("devise_token_auth.confirmations.missing_redirect_url")
            )
          end

          def render_error_not_allowed_redirect_url
            response = {
              status: "error",
              data: resource_data
            }
            message = I18n.t(
              "devise_token_auth.confirmations.not_allowed_redirect_url",
              redirect_url:
            )
            render_error(422, message, response)
          end
      end
    end
  end
end
