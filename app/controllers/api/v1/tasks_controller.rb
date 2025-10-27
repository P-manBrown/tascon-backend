module Api
  module V1
    class TasksController < ApplicationController
      def index
        user_tasks = fetch_tasks_with_task_group
        user_tasks = apply_filter(user_tasks) if params[:filter].present?
        return if user_tasks.nil?

        ordered_tasks = user_tasks.ordered_by_ends_at
        @pagy, tasks = pagy(ordered_tasks, overflow: :last_page)

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

        def apply_filter(tasks)
          case params[:filter]
          when "actionable"
            tasks.actionable
          else
            render_invalid_filter_error
            nil
          end
        end

        def render_invalid_filter_error
          render_custom_error source: "filter", type: "invalid", message: "'filter' には 'actionable' を指定してください。"
        end
    end
  end
end
