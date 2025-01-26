module Api
  module V1
    class UsersController < ApplicationController
      def show
        @user = User.find(params[:id])

        render json: UserResource.new(@user, params: { current_user_contact: }), status: :ok
      end

      def search
        user = User.find_by(email: params[:email], is_private: false)

        if user.nil?
          render json: { user: nil }, status: :ok
        else
          render json: UserResource.new(user), status: :ok
        end
      end

      private
        def current_user_contact
          current_api_v1_user.contacts.find_by(contact_user_id: @user.id)
        end
    end
  end
end
