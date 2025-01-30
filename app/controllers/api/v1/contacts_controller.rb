module Api
  module V1
    class ContactsController < ApplicationController
      def create
        contact = current_api_v1_user.contacts.build(create_contact_params)

        if contact.save
          render json: ContactResource.new(contact), status: :created, location: api_v1_user_url(contact.contact_user)
        else
          render json: ErrorResource.new(contact.errors), status: :unprocessable_entity
        end
      end

      def update
        contact = current_api_v1_user.contacts.find(params[:id])

        if contact.update(update_contact_params)
          render json: ContactResource.new(contact), status: :ok
        else
          render json: ErrorResource.new(contact.errors), status: :unprocessable_entity
        end
      end

      def destroy
        contact = current_api_v1_user.contacts.find(params[:id])
        contact.destroy
        head :no_content
      end

      private
        def create_contact_params
          params.expect(contact: %i[contact_user_id display_name note])
        end

        def update_contact_params
          params.expect(contact: %i[display_name note])
        end
    end
  end
end
