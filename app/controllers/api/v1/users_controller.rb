module Api
  module V1
    class UsersController < ApplicationController
      def show
        # Signed-in users can view other users' profiles, so the lookup is not limited to the current user.
        # nosemgrep: ruby.rails.security.brakeman.check-unscoped-find
        @user = User.find(params[:id])

        render json: UserResource.new(@user, params: {
          current_user_contact: current_user_contact,
          current_user_block: current_user_block,
          suggestion_user_ids: current_api_v1_user.suggestion_user_ids
        }), status: :ok
      end

      def suggestions
        suggestion_users = current_api_v1_user.suggestion_users
        @pagy, users = pagy(suggestion_users, overflow: :last_page)

        render json: UserResource.new(users), status: :ok
      end

      private
        def current_user_contact
          current_api_v1_user.contacts.find_by(contact_user_id: @user.id)
        end

        def current_user_block
          current_api_v1_user.blocks.find_by(blocked_id: @user.id)
        end
    end
  end
end
