module Api
  module V1
    module Auth
      class OmniauthCallbacksController < DeviseTokenAuth::OmniauthCallbacksController
        def omniauth_success
          super
        rescue ActiveRecord::RecordInvalid
          redirect_on_invalid_record
        end

        def omniauth_failure
          redirect_on_failure
        end

        private
          def unsafe_failure_redirect_url
            omniauth_params["failure_redirect_url"] || params["failure_redirect_url"]
          end

          def failure_redirect_url
            return nil if blacklisted_redirect_url?(unsafe_failure_redirect_url) || unsafe_failure_redirect_url.blank?

            unsafe_failure_redirect_url
          end

          def redirect_on_invalid_record
            redirect_to DeviseTokenAuth::Url.generate(failure_redirect_url, err: "omniauth_record_invalid")
          end

          def redirect_on_failure
            if failure_redirect_url
              redirect_to DeviseTokenAuth::Url.generate(failure_redirect_url, err: "omniauth_failure")
            else
              redirect_to DeviseTokenAuth::Url.generate(ENV.fetch("FRONTEND_ORIGIN"), err: "omniauth_failure")
            end
          end

          def assign_provider_attrs(user, auth_hash)
            # Prevent user information from being overwritten during login.
            return unless @oauth_registration

            super
          end
      end
    end
  end
end
