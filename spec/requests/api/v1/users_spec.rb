require "rails_helper"

RSpec.describe "Api::V1::Users" do
  describe "GET /index" do
    it "returns http success" do
      get "/api/v1/users/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/api/v1/users/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /search" do
    it "returns http success" do
      get "/api/v1/users/search"
      expect(response).to have_http_status(:success)
    end
  end
end
