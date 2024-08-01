require "rails_helper"

RSpec.describe "Sessions" do
  describe "POST /api/v1/auth/sign_in" do
    let(:params) { { email: user.email, password: user.password } }

    context "when the user is confirmed" do
      let(:user) { create(:user, :with_confirmed_at) }

      before do
        post "/api/v1/auth/sign_in", params:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "includes access-token, client, and uid in the headers" do
        expect(response.headers).to include("access-token", "client", "uid")
      end
    end

    context "when the user dose not confirmed" do
      let(:user) { create(:user) }

      before do
        post "/api/v1/auth/sign_in", params:
      end

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end

      it "does not include access-token, client, and uid in the headers" do
        expect(response.headers).not_to include("access-token", "client", "uid")
      end
    end
  end

  describe "DELETE /api/v1/auth/sign_out" do
    let(:user) { create(:user, :with_confirmed_at) }
    let(:headers) { user.create_new_auth_token }

    before do
      delete "/api/v1/auth/sign_out", headers:
    end

    it "returns an ok response" do
      expect(response).to have_http_status(:ok)
    end

    it "invalidates the user tokens" do
      user.reload
      expect(user.tokens).to be_empty
    end
  end
end
