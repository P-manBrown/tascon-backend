Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  namespace :api do
    namespace :v1 do
      mount_devise_token_auth_for "User", at: "auth", controllers: {
        confirmations: "api/v1/auth/confirmations",
        omniauth_callbacks: "api/v1/auth/omniauth_callbacks",
        passwords: "api/v1/auth/passwords",
        registrations: "api/v1/auth/registrations",
        token_validations: "api/v1/auth/token_validations"
      }
      resources :users, only: %i[index show] do
        collection do
          get "search"
        end
      end
    end
  end
end
