module Api
  module V1
    class CsrfTokensController < ApplicationController
      skip_before_action :authenticate_api_v1_user!

      def set_csrf_token
        if valid_request_origin?
          render_set_csrf_token_success
        else
          render_invalid_request_origin
        end
      end

      private
        def render_set_csrf_token_success
          render json: { csrf_token: form_authenticity_token }, status: :ok
        end

        def render_invalid_request_origin
          render_error(:unprocessable_entity, "リクエストオリジンが不正です。")
        end
    end
  end
end
