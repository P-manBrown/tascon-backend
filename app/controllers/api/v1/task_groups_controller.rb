module Api
  module V1
    class TaskGroupsController < ApplicationController
      def index
        task_groups = current_api_v1_user.task_groups.order(created_at: :desc)

        render json: TaskGroupResource.new(task_groups), status: :ok
      end

      def show
        task_group = current_api_v1_user.task_groups.find(params[:id])

        render json: TaskGroupResource.new(task_group), status: :ok
      end
    end
  end
end
