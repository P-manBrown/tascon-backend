module Api
  module V1
    class ContactsController < ApplicationController
      before_action :set_user, only: %i[index create]
      before_action :authorize_user_access, only: %i[index create]
      before_action :set_contact, only: %i[update destroy]

      def index
        user_contacts = @user.contacts.includes(contact_user: :avatar_attachment).order(created_at: :desc)
        @pagy, contacts = pagy(user_contacts, limit: 18, overflow: :last_page)

        render json: ContactResource.new(contacts), status: :ok
      end

      def create
        contact = @user.contacts.build(create_contact_params)
        if contact.invalid?
          render_validation_error(contact.errors)
          return
        end
        return unless contact_user_access_allowed?(contact.contact_user)

        contact.save!
        render json: ContactResource.new(contact), status: :created, location: api_v1_user_url(contact.contact_user)
      end

      def update
        if @contact.update(update_contact_params)
          render json: ContactResource.new(@contact), status: :ok
        else
          render_validation_error(@contact.errors)
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

        def contact_user_access_allowed?(contact_user)
          return true if @user.suggestion_users.exists?(contact_user.id)

          if params[:email].blank?
            render_contact_user_id_not_allowed_error
            return false
          end

          if params[:email] != contact_user.email || contact_user.is_private? || @user.blocked_by?(contact_user)
            render_email_user_not_found_error
            return false
          end

          true
        end

        def render_contact_user_id_not_allowed_error
          render_custom_error source: "contact_user_id", type: "not_allowed", message: "メールアドレスで登録してください。"
        end

        def render_email_user_not_found_error
          render_custom_error source: "email", type: "not_found", message: "メールアドレスのユーザーが見つかりません。"
        end
    end
  end
end
