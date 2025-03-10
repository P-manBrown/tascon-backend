module Api
  module V1
    module Auth
      class ConfirmationsController < DeviseTokenAuth::ConfirmationsController
        def create
          return render_create_error_missing_redirect_url if confirmable_enabled? && redirect_url.blank?
          return render_error_not_allowed_redirect_url if blacklisted_redirect_url?(redirect_url)

          super
        end

        private
          def render_create_error_missing_redirect_url
            render_error(422, "'redirect_url' パラメータが与えられていません。")
          end

          def render_error_not_allowed_redirect_url
            response = {
              status: "error",
              data: resource_data
            }
            message = "'#{redirect_url}' へのリダイレクトは許可されていません。"
            render_error(422, message, response)
          end

          def render_create_success
            head :no_content
          end
      end
    end
  end
end
