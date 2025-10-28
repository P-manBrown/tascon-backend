module Api
  module V1
    class TasksController < ApplicationController
      def index
        user_tasks = fetch_tasks_with_task_group.order(Task.arel_table[:ends_at].asc.nulls_last)
        @pagy, tasks = pagy(user_tasks, overflow: :last_page)

        render json: TaskResource.new(tasks, params: { include_task_group: params[:task_group_id].blank? }), status: :ok
      end

      private
        def fetch_tasks_with_task_group
          if params[:task_group_id].present?
            task_group = current_api_v1_user.task_groups.find(params[:task_group_id])
            task_group.tasks
          else
            current_api_v1_user.tasks.includes(:task_group)
          end
        end
    end
  end
end
