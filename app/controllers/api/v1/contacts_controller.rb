module Api
  module V1
    class ContactsController < ApplicationController
      before_action :set_contact, only: %i[update destroy]

      def index
        user_contacts = current_api_v1_user.contacts.includes(contact_user: :avatar_attachment).order(created_at: :DESC)
        @pagy, contacts = pagy(user_contacts, limit: 18, overflow: :last_page)

        render json: ContactResource.new(contacts), status: :ok
      end

      def create
        @contact = current_api_v1_user.contacts.build(create_contact_params)

        if @contact.save
          render json: ContactResource.new(@contact), status: :created, location: api_v1_user_url(@contact.contact_user)
        else
          render_validation_error
        end
      end

      def update
        if @contact.update(update_contact_params)
          render json: ContactResource.new(@contact), status: :ok
        else
          render_validation_error
        end
      end

      def destroy
        @contact.destroy
        head :no_content
      end

      private
        def create_contact_params
          params.expect(contact: %i[contact_user_id display_name note])
        end

        def update_contact_params
          params.expect(contact: %i[display_name note])
        end

        def set_contact
          @contact = current_api_v1_user.contacts.find(params[:id])
        end

        def render_validation_error
          render json: ErrorResource.new(@contact.errors), status: :unprocessable_entity
        end
    end
  end
end
