module Api
  module V1
    class TasksController < ApplicationController
      def index
        user_tasks = current_api_v1_user.tasks.includes(:task_group).order(Task.arel_table[:ends_at].asc.nulls_last)
        @pagy, tasks = pagy(user_tasks, overflow: :last_page)

        render json: TaskResource.new(tasks), status: :ok
      end
    end
  end
end
