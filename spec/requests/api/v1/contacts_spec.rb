require 'rails_helper'

RSpec.describe "Api::V1::Contacts", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/api/v1/contacts/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/api/v1/contacts/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/api/v1/contacts/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
