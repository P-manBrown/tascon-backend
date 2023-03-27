module Api
  module V1
    module Auth
      class RegistrationsController < DeviseTokenAuth::RegistrationsController
        before_action :configure_permitted_parameters

        def update
          @redirect_url = params.fetch(
            :confirm_success_url,
            DeviseTokenAuth.default_confirm_success_url
          )

          if confirmable_enabled? && !@redirect_url
            return render_create_error_missing_confirm_success_url
          end
          if blacklisted_redirect_url?(@redirect_url)
            return render_create_error_redirect_url_not_allowed
          end

          # For setting the redirect URL of the confirmation email.
          @resource.redirect_url = @redirect_url if @resource.present?

          super
        end

        private
          def configure_permitted_parameters
            devise_parameter_sanitizer.permit(:sign_up, keys: %i[name])
            devise_parameter_sanitizer.permit(:account_update, keys: %i[name])
          end
      end
    end
  end
end
