module Api
  module V1
    class TasksController < ApplicationController
      before_action :set_task, only: %i[show update destroy]

      def index
        user_tasks = fetch_tasks
        return if user_tasks.nil?

        ordered_tasks = user_tasks.ordered_by_ends_at
        @pagy, tasks = pagy(ordered_tasks, overflow: :last_page)

        render json: TaskResource.new(tasks, params: { include_task_group: params[:task_group_id].blank? }), status: :ok
      end

      def calendar
        user_tasks = fetch_tasks_for_calendar
        return if user_tasks.nil?

        render json: TaskResource.new(user_tasks, params: { include_task_group: params[:task_group_id].blank? }),
               status: :ok
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

      def destroy
        @task.destroy!
        head :no_content
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

        def fetch_tasks_for_calendar
          date_range = parse_date_range
          return nil if date_range.nil?

          tasks = fetch_tasks
          return nil if tasks.nil?

          tasks.with_dates_set.in_date_range(*date_range)
        end

        def fetch_tasks
          tasks = fetch_tasks_with_task_group
          return tasks if params[:filter].blank?

          apply_filter(tasks)
        end

        def fetch_tasks_with_task_group
          if params[:task_group_id].present?
            task_group = current_api_v1_user.task_groups.find(params[:task_group_id])
            task_group.tasks
          else
            current_api_v1_user.tasks.includes(:task_group)
          end
        end

        def parse_date_range
          return nil unless date_params_present?

          start_date = parse_date(params[:start], "start")
          end_date = parse_date(params[:end], "end")
          return nil if start_date.nil? || end_date.nil?

          if start_date > end_date
            render_invalid_date_range_error
            return nil
          end

          [start_date, end_date]
        end

        def date_params_present?
          if params[:start].blank?
            render_missing_start_param_error
            return false
          end

          if params[:end].blank?
            render_missing_end_param_error
            return false
          end

          true
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

        def parse_date(date_string, param_name)
          Date.parse(date_string)
        rescue Date::Error
          render_custom_error source: param_name, type: "invalid",
                              message: "'#{param_name}' は YYYY-MM-DD 形式で指定してください。"
          nil
        end

        def render_missing_start_param_error
          render_custom_error source: "start", type: "required", message: "'start' パラメータは必須です。"
        end

        def render_missing_end_param_error
          render_custom_error source: "end", type: "required", message: "'end' パラメータは必須です。"
        end

        def render_invalid_filter_error
          render_custom_error source: "filter", type: "invalid", message: "'filter' には 'actionable' を指定してください。"
        end

        def render_invalid_date_range_error
          render_custom_error source: "end", type: "invalid", message: "'end' は 'start' より後の日付を指定してください。"
          nil
        end
    end
  end
end
