module Api
  module V1
    class BlocksController < ApplicationController
      before_action :set_user, only: %i[index create]
      before_action :authorize_user_access, only: %i[index create]

      def index
        user_blocks = @user.blocks.includes(blocked: :avatar_attachment).order(created_at: :desc)

        @pagy, blocks = pagy(user_blocks, limit: 18, overflow: :last_page)
        render json: BlockResource.new(blocks), status: :ok
      end

      def create
        block = @user.blocks.build(create_block_params)

        if block.save
          render json: BlockResource.new(block), status: :created, location: api_v1_user_url(block.blocked)
        else
          render_validation_error(block.errors)
        end
      end

      def destroy
        block = current_api_v1_user.blocks.find(params[:id])

        block.destroy
        head :no_content
      end

      private
        def create_block_params
          params.expect(block: %i[blocked_id])
        end

        def set_user
          @user = User.find(params[:user_id])
        end

        def authorize_user_access
          return if @user == current_api_v1_user

          head :forbidden
        end
    end
  end
end
