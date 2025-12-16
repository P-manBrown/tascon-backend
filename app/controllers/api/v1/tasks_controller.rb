module Api
  module V1
    class TasksController < ApplicationController
      before_action :set_task, only: %i[show update]

      def index
        user_tasks = fetch_tasks_with_task_group
        user_tasks = apply_filter(user_tasks) if params[:filter].present?
        return if user_tasks.nil?

        ordered_tasks = user_tasks.ordered_by_ends_at
        @pagy, tasks = pagy(ordered_tasks, overflow: :last_page)

        render json: TaskResource.new(tasks, params: { include_task_group: params[:task_group_id].blank? }), status: :ok
      end

      def show
        render json: TaskResource.new(@task, params: { include_task_group: true }), status: :ok
      end

      def create
        task_group = current_api_v1_user.task_groups.find(params[:task_group_id])
        task = task_group.tasks.build(create_task_params)

        if task.save
          render json: TaskResource.new(task, params: { include_task_group: true }), status: :created,
                 location: api_v1_task_url(task)
        else
          render_validation_error(task.errors)
        end
      end

      def update
        if @task.update(update_task_params)
          render json: TaskResource.new(@task, params: { include_task_group: true }), status: :ok
        else
          render_validation_error(@task.errors)
        end
      end

      private
        def create_task_params
          params.expect(task: %i[name starts_at ends_at estimated_minutes note])
        end

        def update_task_params
          params.expect(task: %i[name starts_at ends_at time_spent estimated_minutes note status])
        end

        def set_task
          @task = current_api_v1_user.tasks.find(params[:id])
        end

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
