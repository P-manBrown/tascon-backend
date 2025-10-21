module Api
  module V1
    class TaskGroupsController < ApplicationController
      before_action :set_task_group, only: %i[show update destroy]

      def index
        task_groups = current_api_v1_user.task_groups.order(created_at: :desc)

        render json: TaskGroupResource.new(task_groups), status: :ok
      end

      def show
        render json: TaskGroupResource.new(@task_group), status: :ok
      end

      def create
        task_group = current_api_v1_user.task_groups.build(task_group_params)

        if task_group.save
          render json: TaskGroupResource.new(task_group), status: :created, location: api_v1_task_group_url(task_group)
        else
          render_validation_error(task_group.errors)
        end
      end

      def update
        if @task_group.update(task_group_params)
          render json: TaskGroupResource.new(@task_group), status: :ok
        else
          render_validation_error(@task_group.errors)
        end
      end

      def destroy
        @task_group.destroy
        head :no_content
      end

      private
        def task_group_params
          params.expect(task_group: %i[name icon note])
        end

        def set_task_group
          @task_group = current_api_v1_user.task_groups.find(params[:id])
        end
    end
  end
end
