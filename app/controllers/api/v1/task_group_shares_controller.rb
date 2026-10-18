module Api
  module V1
    class TaskGroupSharesController < ApplicationController
      before_action :set_task_group_share, only: :show

      def index
        task_group_shares = current_api_v1_user.task_group_shares
                                               .without_blocked_owners(current_api_v1_user)
                                               .includes(task_group: { user: :avatar_attachment })
                                               .order(created_at: :desc)

        render json: TaskGroupShareResource.new(task_group_shares), status: :ok
      end

      def show
        render json: TaskGroupShareResource.new(@task_group_share), status: :ok
      end

      private
        def set_task_group_share
          @task_group_share = current_api_v1_user.task_group_shares
                                                 .without_blocked_owners(current_api_v1_user)
                                                 .includes(task_group: { user: :avatar_attachment })
                                                 .find(params[:id])
        end
    end
  end
end
