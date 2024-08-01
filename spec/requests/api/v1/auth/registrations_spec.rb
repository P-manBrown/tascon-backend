require "rails_helper"

RSpec.describe "Registrations" do
  describe "POST /api/v1/auth" do
    context "when the redirect URL is whitelisted" do
      let(:params) do
        attributes_for(:user, confirm_success_url: ENV.fetch("FRONTEND_ORIGIN"))
      end

      before do
        post "/api/v1/auth", params:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "sends a confirmation email" do
        expect(ActionMailer::Base.deliveries.count).to eq(1)
      end
    end

    context "when the redirect URL is not whitelisted" do
      let(:params) do
        attributes_for(:user, confirm_success_url: "http://blacklisted.com/bad")
      end

      before do
        post "/api/v1/auth", params:
      end

      it "returns an unprocessable_entity response" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not send a confirmation email" do
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end
  end

  describe "PATCH /api/v1/auth" do
    let(:user) { create(:user, :with_confirmed_at) }
    let(:headers) { user.create_new_auth_token }
    let(:params) do
      {
        name: "updated #{user.name}",
        email: "updated.#{user.email}",
        confirm_success_url: ENV.fetch("FRONTEND_ORIGIN")
      }
    end

    context "when the user is authenticated" do
      before do
        patch "/api/v1/auth", headers:, params:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "updates the name with new attributes" do
        user.reload
        expect(user.name).to eq(params[:name])
      end

      it "stores the new email in unconfirmed_email" do
        user.reload
        expect(user.unconfirmed_email).to eq(params[:email])
      end

      it "sends a confirmation email" do
        expect(ActionMailer::Base.deliveries.count).to eq(1)
      end

      it "sets the redirect URL in the confirmation email" do
        mail = ActionMailer::Base.deliveries.last
        redirect_url = CGI.escape(params[:confirm_success_url])
        expect(mail.body).to include(redirect_url)
      end
    end

    context "when the user is not authenticated" do
      before do
        patch "/api/v1/auth", params:
      end

      it "returns a not_found response" do
        expect(response).to have_http_status(:not_found)
      end

      it "does not update the name with new attributes" do
        user.reload
        expect(user.name).not_to eq(params[:name])
      end

      it "does not send a confirmation email" do
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end

    context "when the redirect URL is not whitelisted" do
      let(:params) do
        {
          name: "updated #{user.name}",
          email: "updated.#{user.email}",
          confirm_success_url: "http://blacklisted.com/bad"
        }
      end

      before do
        patch "/api/v1/auth", params:
      end

      it "returns an unprocessable_entity response" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not update the name with new attributes" do
        user.reload
        expect(user.name).not_to eq(params[:name])
      end

      it "does not send a confirmation email" do
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end

    context "when the new email is the same as the current email" do
      let(:params) do
        {
          name: "updated #{user.name}",
          email: user.email,
          confirm_success_url: ENV.fetch("FRONTEND_ORIGIN")
        }
      end

      before do
        patch "/api/v1/auth", headers:, params:
      end

      it "updates the name with new attributes" do
        user.reload
        expect(user.name).to eq(params[:name])
      end

      it "stores the new email in unconfirmed_email" do
        user.reload
        expect(user.unconfirmed_email).to be_nil
      end

      it "does not send a confirmation email" do
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end
  end

  describe "DELETE /api/v1/auth" do
    let(:user) { create(:user, :with_confirmed_at) }
    let(:headers) { user.create_new_auth_token }

    context "when the user is authenticated" do
      before do
        delete "/api/v1/auth", headers:
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end

      it "deletes the user" do
        expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the user is not authenticated" do
      before do
        delete "/api/v1/auth"
      end

      it "returns a not_found response" do
        expect(response).to have_http_status(:not_found)
      end

      it "does not delete the user" do
        expect { user.reload }.not_to raise_error
      end
    end
  end
end
