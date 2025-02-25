module Api
  module V1
    module Auth
      class SessionsController < DeviseTokenAuth::SessionsController
        private
          def render_create_success
            render json: AccountResource.new(@resource), status: :ok
          end
      end
    end
  end
end
