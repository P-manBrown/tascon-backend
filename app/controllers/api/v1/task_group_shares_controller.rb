module Api
  module V1
    class TaskGroupSharesController < ApplicationController
      def index
        task_group_shares = current_api_v1_user.task_group_shares
                                               .without_blocked_owners(current_api_v1_user)
                                               .includes(task_group: { user: :avatar_attachment })
                                               .order(created_at: :desc)

        render json: TaskGroupShareResource.new(task_group_shares), status: :ok
      end
    end
  end
end
