require "rails_helper"

RSpec.describe "Users" do
  let(:current_user) { create(:user, :with_confirmed_at) }
  let(:headers) { current_user.create_new_auth_token.merge(origin_header) }

  describe "GET /api/v1/users/:id" do
    let(:user) { create(:user) }

    context "when the user and the current user have registered each other as contacts" do
      let!(:contact) do
        create(:contact, user: current_user, contact_user: user, display_name: "Teammate", note: "Shares tasks")
      end

      before do
        create(:contact, user:, contact_user: current_user)
        get "/api/v1/users/#{user.id}", headers:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "includes the contact registered by the current user" do
        expect(response.parsed_body.dig("user", "contact")).to eq(
          "id" => contact.id, "display_name" => contact.display_name, "note" => contact.note
        )
      end

      it "does not mark the user as suggested" do
        expect(response.parsed_body.dig("user", "is_suggested")).to be(false)
      end
    end

    context "when the current user has blocked a user who registered the current user as a contact" do
      let!(:block) { current_user.blocks.create!(blocked: user) }

      before do
        create(:contact, user:, contact_user: current_user)
        get "/api/v1/users/#{user.id}", headers:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "includes the block created by the current user" do
        expect(response.parsed_body.dig("user", "block")).to eq("id" => block.id)
      end

      it "does not mark the user as suggested" do
        expect(response.parsed_body.dig("user", "is_suggested")).to be(false)
      end
    end

    context "when the user has registered the current user as a contact" do
      before do
        create(:contact, user:, contact_user: current_user)
        get "/api/v1/users/#{user.id}", headers:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "marks the user as suggested" do
        expect(response.parsed_body.dig("user", "is_suggested")).to be(true)
      end
    end

    context "when the user has no relationship with the current user" do
      let(:user) { create(:user, bio: "Plans the team's weekly tasks") }

      before do
        get "/api/v1/users/#{user.id}", headers:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns only the public attributes of the user" do
        expect(response.parsed_body["user"]).to eq(
          "id" => user.id, "name" => user.name, "bio" => user.bio, "is_suggested" => false
        )
      end
    end

    context "when the user does not exist" do
      let(:user) { create(:user).tap(&:destroy) }

      before do
        get "/api/v1/users/#{user.id}", headers:
      end

      it "returns a not_found response" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the request is not authenticated" do
      before do
        get "/api/v1/users/#{user.id}", headers: origin_header
      end

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/users/suggestions" do
    context "when users in each relationship state exist" do
      let(:suggested_user) { create(:user) }

      before do
        create(:contact, user: suggested_user, contact_user: current_user)

        mutual_contact_user = create(:user)
        create(:contact, user: mutual_contact_user, contact_user: current_user)
        create(:contact, user: current_user, contact_user: mutual_contact_user)

        blocked_user = create(:user)
        create(:contact, user: blocked_user, contact_user: current_user)
        current_user.blocks.create!(blocked: blocked_user)

        create(:user)

        get "/api/v1/users/suggestions", headers:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "lists only the suggested user" do
        expect(response.parsed_body["users"].pluck("id")).to contain_exactly(suggested_user.id)
      end
    end

    context "when the suggestion users fill more than one page" do
      before do
        19.times { create(:contact, user: create(:user), contact_user: current_user) }
        get "/api/v1/users/suggestions", headers:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "lists 18 users" do
        expect(response.parsed_body["users"].size).to eq(18)
      end

      it "returns the total count in the headers" do
        expect(response.headers["Total-Count"]).to eq("19")
      end

      it "returns the total pages in the headers" do
        expect(response.headers["Total-Pages"]).to eq("2")
      end
    end

    context "when the second page is requested" do
      before do
        19.times { create(:contact, user: create(:user), contact_user: current_user) }
        get "/api/v1/users/suggestions", headers:, params: { page: 2 }
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "lists 1 user" do
        expect(response.parsed_body["users"].size).to eq(1)
      end

      it "returns the current page in the headers" do
        expect(response.headers["Current-Page"]).to eq("2")
      end
    end

    context "when a page past the last page is requested" do
      before do
        19.times { create(:contact, user: create(:user), contact_user: current_user) }
        get "/api/v1/users/suggestions", headers:, params: { page: 3 }
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "lists the 1 user of the last page" do
        expect(response.parsed_body["users"].size).to eq(1)
      end

      it "returns the last page as the current page in the headers" do
        expect(response.headers["Current-Page"]).to eq("2")
      end
    end

    context "when the request is not authenticated" do
      before do
        get "/api/v1/users/suggestions", headers: origin_header
      end

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
