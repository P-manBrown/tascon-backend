module Api
  module V1
    class ContactsController < ApplicationController
      before_action :set_user, only: %i[index create]
      before_action :authorize_user_access, only: %i[index create]
      before_action :set_contact, only: %i[update destroy]

      def index
        user_contacts = @user.contacts.includes(contact_user: :avatar_attachment).order(created_at: :desc)
        @pagy, contacts = pagy(user_contacts, overflow: :last_page)

        render json: ContactResource.new(contacts), status: :ok
      end

      def create
        contact = build_contact
        return if contact.nil?

        contact_user = contact.contact_user
        return if contact_user.present? && !contact_user_exists?(contact_user) && !contact_user_valid?(contact_user)

        if contact.save
          render json: ContactResource.new(contact), status: :created, location: api_v1_user_url(contact_user)
        else
          render_validation_error(contact.errors)
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
        @contact.destroy!
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

        def build_contact
          return @user.contacts.build(create_contact_params) if params[:contact_user_id].present?

          target_user = find_user_by_email
          if target_user.nil?
            render_registration_failed_error
            return nil
          end
          @user.contacts.build(create_contact_params.merge(contact_user_id: target_user.id))
        end

        def find_user_by_email
          return nil if params[:email].blank?

          User.find_by(email: params[:email])
        end

        def contact_user_exists?(contact_user)
          @user.contacts.exists?(contact_user: contact_user)
        end

        def contact_user_valid?(contact_user)
          return registrable_by_id?(contact_user) if params[:email].blank?

          if params[:contact_user_id].present? && params[:email].present?
            email_consistent?(contact_user) && accessible?(contact_user)
          else
            accessible?(contact_user)
          end
        end

        def registrable_by_id?(contact_user)
          unless @user.suggestion_users.exists?(contact_user.id)
            render_email_required_error
            return false
          end

          true
        end

        def email_consistent?(contact_user)
          if params[:email] != contact_user.email
            render_registration_failed_error
            return false
          end

          true
        end

        def accessible?(contact_user)
          if contact_user.is_private? || @user.blocked_by?(contact_user)
            render_registration_failed_error
            return false
          end

          true
        end

        def render_registration_failed_error
          render_custom_error source: "contact_user", type: "invalid", message: "ユーザーを登録できませんでした。"
        end

        def render_email_required_error
          render_custom_error source: "email", type: "required", message: "メールアドレスが必要です。"
        end
    end
  end
end
