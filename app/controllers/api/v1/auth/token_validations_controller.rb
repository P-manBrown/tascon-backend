module Api
  module V1
    module Auth
      class TokenValidationsController < DeviseTokenAuth::TokenValidationsController
        private
          def render_validate_token_success
            render json: AccountResource.new(@resource), status: :ok
          end
      end
    end
  end
end
