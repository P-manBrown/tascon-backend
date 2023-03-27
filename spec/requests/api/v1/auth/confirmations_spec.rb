require "rails_helper"

RSpec.describe "Confirmations" do
  describe "POST /api/v1/auth/confirmation" do
    let(:user) { create(:user, :with_confirmed_at) }

    context "when the redirect URL is whitelisted" do
      let(:params) do
        { email: user.email, redirect_url: ENV.fetch("FRONTEND_ORIGIN") }
      end

      before do
        post "/api/v1/auth/confirmation", params:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "re-sends a confirmatin email" do
        expect(ActionMailer::Base.deliveries.count).to eq(1)
      end
    end

    context "when the redirect URL is not whitelisted" do
      let(:params) do
        { email: user.email, redirect_url: "http://blacklisted.com/bad" }
      end

      before do
        post "/api/v1/auth/confirmation", params:
      end

      it "returns an unprocessable_entity response" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not send a confirmation email" do
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end
  end

  describe "GET /api/v1/auth/confirmation" do
    let(:user) { create(:user) }
    let(:confirmation_url) do
      path = "/api/v1/auth/confirmation"
      token = user.confirmation_token
      url = ENV.fetch("FRONTEND_ORIGIN")
      "#{path}?confirmation_token=#{token}&redirect_url=#{url}"
    end

    before do
      get confirmation_url
    end

    it "returns a found status" do
      expect(response).to have_http_status(:found)
    end

    it "stores a value in confirmed_at" do
      user.reload
      expect(user.confirmed_at).not_to be_nil
    end

    context "when the user has an unconfirmed email" do
      let(:user) { create(:user, :with_unconfirmed_email) }

      it "updates the email to the unconfirmed_email" do
        unconfirmed_email = user.unconfirmed_email
        user.reload
        expect(user.email).to eq(unconfirmed_email)
      end

      it "clears the unconfirmed_email" do
        user.reload
        expect(user.unconfirmed_email).to be_nil
      end
    end
  end
end
