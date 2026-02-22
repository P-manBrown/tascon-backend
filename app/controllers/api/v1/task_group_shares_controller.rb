module Api
  module V1
    class TaskGroupSharesController < ApplicationController
      before_action :set_task_group_share, only: :show
      before_action :set_tasks, only: %i[tasks task calendar]

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

      def calendar
        calendar_tasks = fetch_tasks_for_calendar
        return if calendar_tasks.nil?

        render json: TaskResource.new(calendar_tasks, params: { include_task_group: false }), status: :ok
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

        def fetch_tasks_for_calendar
          date_range = parse_date_range
          return nil if date_range.nil?

          @tasks.with_dates_set.in_date_range(*date_range).ordered_by_ends_at
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

        def render_invalid_date_range_error
          render_custom_error source: "end", type: "invalid", message: "'end' は 'start' より後の日付を指定してください。"
        end
    end
  end
end
