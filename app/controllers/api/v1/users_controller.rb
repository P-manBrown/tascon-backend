module Api
  module V1
    class UsersController < ApplicationController
      def show
        user = User.find(params[:id])

        render json: UserResource.new(user), status: :ok
      end
    end
  end
end
