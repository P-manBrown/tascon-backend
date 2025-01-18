module Api
  module V1
    class ContactsController < ApplicationController
      def create
        contact = current_api_v1_user.contacts.build(contact_params)

        if contact.save
          render json: ContactResource.new(contact), status: :created, location: api_v1_contact_url(contact)
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
        def contact_params
          params.require(:contact).permit(:contact_user_id)
        end
    end
  end
end
