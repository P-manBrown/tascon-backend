module Api
  module V1
    class UsersController < ApplicationController
      def show
        user = User.find(params[:id])

        render json: UserResource.new(user), status: :ok
      end

      def search
        user = User.find_by(email: params[:email], is_private: false)

        if user.nil?
          render json: { user: nil }, status: :ok
        else
          render json: UserResource.new(user), status: :ok
        end
      end
    end
  end
end
