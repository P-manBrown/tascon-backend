require "rails_helper"

RSpec.describe "Passwords" do
  describe "PATCH /auth/password" do
    let(:user) { create(:user) }
    let(:headers) { user.create_new_auth_token }
    let(:params) do
      new_password = "updated #{user.password}"
      {
        password: new_password,
        password_confirmation: new_password
      }
    end

    context "when the user is authenticated" do
      before do
        patch "/api/v1/auth/password", headers:, params:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "changes the password" do
        user.reload
        expect(user).to be_valid_password(params[:password])
      end
    end

    context "when the user is not authenticated" do
      before do
        patch "/api/v1/auth/password", params:
      end

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end

      it "does not change the password" do
        user.reload
        expect(user).not_to be_valid_password(params[:password])
      end
    end

    context "when password and password_confirmation do not match" do
      let(:params) do
        {
          password: "updated #{user.password}",
          password_confirmation: "wrong_confirmation"
        }
      end

      before do
        patch "/api/v1/auth/password", headers:, params:
      end

      it "returns an unprocessable_entity response" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not change the password" do
        user.reload
        expect(user).not_to be_valid_password(params[:password])
      end
    end
  end

  describe "POST /auth/password" do
    let(:user) { create(:user) }

    context "when the redirect URL is whitelisted" do
      let(:params) do
        {
          email: user.email,
          redirect_url: ENV.fetch("FRONTEND_ORIGIN")
        }
      end

      before do
        post "/api/v1/auth/password", params:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "stores a value in reset_password_token" do
        user.reload
        expect(user.reset_password_token).not_to be_nil
      end

      it "sends a password reset email" do
        expect(ActionMailer::Base.deliveries.count).to eq(1)
      end
    end

    context "when the redirect URL is not whitelisted" do
      let(:params) do
        {
          email: user.email,
          redirect_url: "http://blacklisted.com/bad"
        }
      end

      before do
        post "/api/v1/auth/password", params:
      end

      it "returns an unprocessable_entity response" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not send a confirmation email" do
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end
  end

  describe "GET /auth/password/edit" do
    let(:user) { create(:user) }
    let(:reset_password_url) do
      path = "/api/v1/auth/password/edit"
      token = user.send_reset_password_instructions
      url = ENV.fetch("FRONTEND_ORIGIN")
      "#{path}?reset_password_token=#{token}&redirect_url=#{url}"
    end

    before do
      get reset_password_url
    end

    it "returns a found status" do
      expect(response).to have_http_status(:found)
    end

    it "changes to true in allow_password_change" do
      user.reload
      expect(user.allow_password_change).to be_truthy
    end
  end
end
