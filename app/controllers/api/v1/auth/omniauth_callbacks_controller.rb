module Api
  module V1
    module Auth
      class OmniauthCallbacksController <
        DeviseTokenAuth::OmniauthCallbacksController
        def omniauth_success
          super
          auth_header = @resource.build_auth_headers(@token.token, @token.client)
          set_cookie(auth_header)
        end
      end
    end
  end
end
