module Api
  module V1
    class ContactsController < ApplicationController
      before_action :set_contact, only: %i[update destroy]
      before_action :set_reverse_contact, only: %i[block unblock]

      def index
        user_contacts = current_api_v1_user.contacts_with_users.order(created_at: :desc)
        @pagy, contacts = pagy(user_contacts, limit: 18, overflow: :last_page)

        render json: ContactResource.new(contacts), status: :ok
      end

      def blocked
        blocked_contacts = current_api_v1_user.blocked_contacts_with_users.order(blocked_at: :desc)
        @pagy, contacts = pagy(blocked_contacts, limit: 18, overflow: :last_page)

        render json: ContactResource.new(contacts), status: :ok
      end

      def create
        target_user = find_target_user
        return if target_user.nil?

        @contact = current_api_v1_user.contacts.build(create_contact_params.merge(contact_user: target_user))

        if @contact.save
          render json: ContactResource.new(@contact), status: :created, location: api_v1_user_url(@contact.contact_user)
        else
          render_validation_error(@contact.errors)
        end
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

      def block
        if @contact.update_blocked_status(true)
          render json: ContactResource.new(@contact), status: :ok
        else
          render_validation_error(@contact.errors)
        end
      end

      def unblock
        if @contact.update_blocked_status(false)
          render json: ContactResource.new(@contact), status: :ok
        else
          render_validation_error(@contact.errors)
        end
      end

      private
        def create_contact_params
          params.expect(contact: %i[display_name note])
        end

        def update_contact_params
          params.expect(contact: %i[display_name note])
        end

        def set_contact
          @contact = current_api_v1_user.contacts.find(params[:id])
        end

        def set_reverse_contact
          @contact = current_api_v1_user.reverse_contacts.find(params[:id])
        end

        def find_target_user
          if params[:contact_user_id].present? && params[:email].blank?
            find_target_user_by_id
          else
            find_target_user_by_email
          end
        end

        def find_target_user_by_id
          target_user = current_api_v1_user.find_suggestion_user(params[:contact_user_id])
          if target_user.nil?
            render_contact_user_id_not_allowed_error
            return
          end

          target_user
        end

        def find_target_user_by_email
          if params[:email].blank?
            render_missing_email_error
            return
          end

          target_user = User.find_public_by_email(params[:email])
          if target_user.nil?
            render_email_user_not_found_error
            return
          end

          target_user
        end

        def render_missing_email_error
          render_custom_error attribute: "email", type: "blank", message: "メールアドレスを入力してください。"
        end

        def render_email_user_not_found_error
          render_custom_error attribute: "email", type: "not_found", message: "メールアドレスのユーザーが見つかりません。"
        end

        def render_contact_user_id_not_allowed_error
          render_custom_error attribute: "contact_user_id", type: "not_allowed", message: "メールアドレスで登録してください。"
        end
    end
  end
end
