module Api
  module V1
    module Auth
      class TokenValidationsController < DeviseTokenAuth::TokenValidationsController
        private
          def render_validate_token_success
            token_validation_response = @resource.token_validation_response.merge(avatar_url: @resource.avatar_url)
            render json: {
              success: true,
              data: resource_data(resource_json: token_validation_response)
            }
          end
      end
    end
  end
end
