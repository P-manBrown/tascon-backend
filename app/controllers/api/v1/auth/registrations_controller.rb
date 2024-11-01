module Api
  module V1
    module Auth
      class RegistrationsController < DeviseTokenAuth::RegistrationsController
        # See https://github.com/lynndylanhurley/devise_token_auth/issues/432
        prepend_before_action :configure_permitted_parameters

        def update
          return render_update_error_user_not_found if @resource.blank?

          if should_set_redirect_url?
            @redirect_url = confirm_success_url
            return render_create_error_missing_confirm_success_url if @redirect_url.blank?
            return render_create_error_redirect_url_not_allowed if blacklisted_redirect_url?(@redirect_url)

            set_redirect_url
          end

          super
        end

        def destroy
          super do
            if DeviseTokenAuth.cookie_enabled
              cookies.delete(DeviseTokenAuth.cookie_name, domain: DeviseTokenAuth.cookie_attributes[:domain])
            end
          end
        end

        private
          def should_set_redirect_url?
            new_email = account_update_params[:email]
            new_email.present? && @resource.email != new_email && confirmable_enabled?
          end

          def confirm_success_url
            params.fetch(:confirm_success_url, DeviseTokenAuth.default_confirm_success_url)
          end

          def set_redirect_url
            @resource.redirect_url = @redirect_url if @resource.present?
          end

          def render_update_success
            render json: {
              status: "success",
              data: resource_data(resource_json: @resource.as_json.merge(avatar_url: @resource.avatar_url))
            }
          end

          def resource_errors
            @resource.errors.full_messages
          end

          def configure_permitted_parameters
            devise_parameter_sanitizer.permit(:sign_up, keys: %i[name])
            devise_parameter_sanitizer.permit(:account_update, keys: %i[name avatar bio is_private])
          end
      end
    end
  end
end
