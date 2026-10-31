require "rails_helper"

RSpec.describe "Contacts" do
  let(:current_user) { create(:user, :with_confirmed_at) }
  let(:headers) { current_user.create_new_auth_token.merge(origin_header) }

  describe "GET /api/v1/users/:user_id/contacts" do
    context "when the current user has contacts" do
      let!(:older_contact) do
        create(:contact, user: current_user, contact_user: create(:user), created_at: 2.days.ago)
      end
      let!(:newer_contact) do
        create(:contact, user: current_user, contact_user: create(:user), created_at: 1.day.ago)
      end

      before do
        create(:contact, user: create(:user), contact_user: create(:user))
        get "/api/v1/users/#{current_user.id}/contacts", headers:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "lists only the contacts of the current user, newest first" do
        expect(response.parsed_body["contacts"].pluck("id")).to eq([newer_contact.id, older_contact.id])
      end
    end

    context "when the contacts fill more than one page" do
      before do
        19.times { create(:contact, user: current_user, contact_user: create(:user)) }
        get "/api/v1/users/#{current_user.id}/contacts", headers:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "lists 18 contacts" do
        expect(response.parsed_body["contacts"].size).to eq(18)
      end

      it "returns the total count in the headers" do
        expect(response.headers["Total-Count"]).to eq("19")
      end
    end

    context "when the user is not the current user" do
      before do
        get "/api/v1/users/#{create(:user).id}/contacts", headers:
      end

      it "returns a forbidden response" do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the user does not exist" do
      before do
        user = create(:user).tap(&:destroy)
        get "/api/v1/users/#{user.id}/contacts", headers:
      end

      it "returns a not_found response" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the request is not authenticated" do
      before do
        get "/api/v1/users/#{current_user.id}/contacts", headers: origin_header
      end

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/users/:user_id/contacts" do
    let(:path) { "/api/v1/users/#{current_user.id}/contacts" }
    let(:registration_failed_error) do
      { "source" => "contact_user", "type" => "invalid", "message" => "ユーザーを登録できませんでした。" }
    end

    context "when a suggested user is registered by ID" do
      let(:user) { create(:user) }

      before do
        create(:contact, user:, contact_user: current_user)
        params = { contact_user_id: user.id, display_name: "Teammate", note: "Shares tasks" }
        post path, params:, headers:, as: :json
      end

      it "returns a created response" do
        expect(response).to have_http_status(:created)
      end

      it "returns the URL of the registered user in the Location header" do
        expect(response.headers["Location"]).to eq("http://www.example.com/api/v1/users/#{user.id}")
      end

      it "returns the registered user" do
        expect(response.parsed_body.dig("contact", "contact_user", "id")).to eq(user.id)
      end

      it "stores the display name and the note" do
        expect(current_user.contacts.find_by(contact_user: user)).to have_attributes(
          display_name: "Teammate", note: "Shares tasks"
        )
      end
    end

    context "when a user is registered by ID and the user's email" do
      let(:user) { create(:user, is_private: false) }

      before do
        params = { contact_user_id: user.id, email: user.email, display_name: "Teammate" }
        post path, params:, headers:, as: :json
      end

      it "returns a created response" do
        expect(response).to have_http_status(:created)
      end

      it "registers the user as a contact of the current user" do
        expect(current_user.contacts.pluck(:contact_user_id)).to contain_exactly(user.id)
      end
    end

    context "when a user is registered by email" do
      let(:user) { create(:user, is_private: false) }

      before do
        post path, params: { email: user.email, display_name: "Teammate" }, headers:, as: :json
      end

      it "returns a created response" do
        expect(response).to have_http_status(:created)
      end

      it "registers the user as a contact of the current user" do
        expect(current_user.contacts.pluck(:contact_user_id)).to contain_exactly(user.id)
      end
    end

    context "when a user who is not suggested is registered by ID only" do
      before do
        user = create(:user, is_private: false)
        post path, params: { contact_user_id: user.id, display_name: "Teammate" }, headers:, as: :json
      end

      it "returns an unprocessable_content response" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns the email required error" do
        expect(response.parsed_body["error"]).to eq(
          "source" => "email", "type" => "required", "message" => "メールアドレスが必要です。"
        )
      end
    end

    context "when the email is not the email of the user of the ID" do
      before do
        user = create(:user, is_private: false)
        other_user = create(:user, is_private: false)
        params = { contact_user_id: user.id, email: other_user.email, display_name: "Teammate" }
        post path, params:, headers:, as: :json
      end

      it "returns an unprocessable_content response" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns the registration failed error" do
        expect(response.parsed_body["error"]).to eq(registration_failed_error)
      end
    end

    context "when the user is private" do
      before do
        user = create(:user)
        post path, params: { email: user.email, display_name: "Teammate" }, headers:, as: :json
      end

      it "returns an unprocessable_content response" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns the registration failed error" do
        expect(response.parsed_body["error"]).to eq(registration_failed_error)
      end
    end

    context "when the user has blocked the current user" do
      before do
        user = create(:user, is_private: false)
        user.blocks.create!(blocked: current_user)
        post path, params: { email: user.email, display_name: "Teammate" }, headers:, as: :json
      end

      it "returns an unprocessable_content response" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns the registration failed error" do
        expect(response.parsed_body["error"]).to eq(registration_failed_error)
      end
    end

    context "when the current user registers themself" do
      before do
        current_user.update!(is_private: false)
        post path, params: { email: current_user.email, display_name: "Me" }, headers:, as: :json
      end

      it "returns an unprocessable_content response" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns the self contact error" do
        expect(response.parsed_body["errors"]).to contain_exactly(
          a_hash_including("source" => "contact_user", "type" => "cannot_add_self_contact")
        )
      end
    end

    context "when the current user has blocked the user" do
      before do
        user = create(:user, is_private: false)
        current_user.blocks.create!(blocked: user)
        post path, params: { email: user.email, display_name: "Teammate" }, headers:, as: :json
      end

      it "returns an unprocessable_content response" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns the blocked user error" do
        expect(response.parsed_body["errors"]).to contain_exactly(
          a_hash_including("source" => "contact_user", "type" => "cannot_add_blocked_user")
        )
      end
    end

    context "when the user is already registered" do
      before do
        user = create(:user, is_private: false)
        create(:contact, user: current_user, contact_user: user)
        post path, params: { contact_user_id: user.id, display_name: "Teammate" }, headers:, as: :json
      end

      it "returns an unprocessable_content response" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns the taken error" do
        expect(response.parsed_body["errors"]).to contain_exactly(
          a_hash_including("source" => "contact_user_id", "type" => "taken")
        )
      end
    end

    context "when the user is not the current user" do
      before do
        user = create(:user)
        create(:contact, user:, contact_user: current_user)
        params = { contact_user_id: user.id, display_name: "Teammate" }
        post "/api/v1/users/#{create(:user).id}/contacts", params:, headers:, as: :json
      end

      it "returns a forbidden response" do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the request is not authenticated" do
      before do
        user = create(:user)
        create(:contact, user:, contact_user: current_user)
        post path, params: { contact_user_id: user.id, display_name: "Teammate" }, headers: origin_header, as: :json
      end

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/contacts/:id" do
    context "when the contact belongs to the current user" do
      let(:contact) do
        contact_user = create(:user)
        create(:contact, user: current_user, contact_user:, display_name: "Teammate", note: "Shares tasks")
      end

      before do
        params = { display_name: "Manager", note: "Reviews tasks" }
        patch "/api/v1/contacts/#{contact.id}", params:, headers:, as: :json
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "stores the new display name and note" do
        expect(contact.reload).to have_attributes(display_name: "Manager", note: "Reviews tasks")
      end

      it "returns the updated contact" do
        expect(response.parsed_body.dig("contact", "display_name")).to eq("Manager")
      end
    end

    context "when the contact belongs to another user" do
      let(:contact) { create(:contact, user: create(:user), contact_user: create(:user), display_name: "Teammate") }

      before do
        patch "/api/v1/contacts/#{contact.id}", params: { display_name: "Manager" }, headers:, as: :json
      end

      it "returns a not_found response" do
        expect(response).to have_http_status(:not_found)
      end

      it "does not change the contact" do
        expect(contact.reload.display_name).to eq("Teammate")
      end
    end

    context "when the request is not authenticated" do
      before do
        contact = create(:contact, user: current_user, contact_user: create(:user))
        patch "/api/v1/contacts/#{contact.id}", params: { display_name: "Manager" }, headers: origin_header, as: :json
      end

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/contacts/:id" do
    context "when the contact belongs to the current user" do
      let(:contact) { create(:contact, user: current_user, contact_user: create(:user)) }

      before do
        delete "/api/v1/contacts/#{contact.id}", headers:
      end

      it "returns a no_content response" do
        expect(response).to have_http_status(:no_content)
      end

      it "deletes the contact" do
        expect(Contact).not_to exist(contact.id)
      end
    end

    context "when the contact belongs to another user" do
      let(:contact) { create(:contact, user: create(:user), contact_user: create(:user)) }

      before do
        delete "/api/v1/contacts/#{contact.id}", headers:
      end

      it "returns a not_found response" do
        expect(response).to have_http_status(:not_found)
      end

      it "keeps the contact" do
        expect(Contact).to exist(contact.id)
      end
    end

    context "when the request is not authenticated" do
      before do
        contact = create(:contact, user: current_user, contact_user: create(:user))
        delete "/api/v1/contacts/#{contact.id}", headers: origin_header
      end

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
