module Api
  module V1
    class ContactsController < ApplicationController
      before_action :set_contact, only: %i[update destroy block unblock]

      def index
        user_contacts = current_api_v1_user.contacts.includes(contact_user: :avatar_attachment).order(created_at: :desc)
        @pagy, contacts = pagy(user_contacts, limit: 18, overflow: :last_page)

        render json: ContactResource.new(contacts), status: :ok
      end

      def blocked
        blocked_contacts = current_api_v1_user.contacts.blocked
                                              .includes(contact_user: :avatar_attachment)
                                              .order(blocked_at: :desc)
        @pagy, contacts = pagy(blocked_contacts, limit: 18, overflow: :last_page)

        render json: ContactResource.new(contacts), status: :ok
      end

      def create
        target_user = User.find_by(email: params[:email], is_private: false)

        return render_user_not_found_error unless target_user

        @contact = current_api_v1_user.contacts.build(create_contact_params.merge(contact_user: target_user))

        if @contact.save
          render json: ContactResource.new(@contact), status: :created,
                 location: api_v1_user_url(@contact.contact_user)
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

      def block
        if @contact.update(blocked_at: Time.current)
          render json: ContactResource.new(@contact), status: :ok
        else
          render_validation_error
        end
      end

      def unblock
        if @contact.update(blocked_at: nil)
          render json: ContactResource.new(@contact), status: :ok
        else
          render_validation_error
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

        def render_user_not_found_error
          error_obj = {
            attribute: "email",
            type: "not_found",
            full_message: "メールアドレスのユーザーが見つかりません。"
          }
          render json: ErrorResource.new(error_obj), status: :unprocessable_entity
        end

        def render_validation_error
          render json: ErrorResource.new(@contact.errors), status: :unprocessable_entity
        end
    end
  end
end
