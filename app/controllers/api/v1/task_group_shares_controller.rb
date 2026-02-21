module Api
  module V1
    class TaskGroupSharesController < ApplicationController
      before_action :set_task_group_share, only: :show
      before_action :set_tasks, only: %i[tasks task]

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

      def tasks
        ordered_tasks = @tasks.completed_last.ordered_by_ends_at

        @pagy, paginated_tasks = pagy(ordered_tasks, overflow: :last_page)

        render json: TaskResource.new(paginated_tasks, params: { include_task_group: false }), status: :ok
      end

      def task
        task = @tasks.find(params[:task_id])

        render json: TaskResource.new(task, params: { include_task_group: true }), status: :ok
      end

      private
        def set_task_group_share
          @task_group_share = current_api_v1_user.task_group_shares
                                                 .without_blocked_owners(current_api_v1_user)
                                                 .includes(task_group: { user: :avatar_attachment })
                                                 .find(params[:id])
        end

        def set_tasks
          task_group_share = current_api_v1_user.task_group_shares
                                                .without_blocked_owners(current_api_v1_user)
                                                .find(params[:id])
          @tasks = task_group_share.task_group.tasks
        end
    end
  end
end
