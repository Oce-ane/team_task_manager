# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Auth", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }

  describe "POST /api/auth/register" do
    let(:valid_params) do
      { user: { email: "alice@example.com", name: "Alice", password: "password123" } }
    end

    context "with valid params" do
      it "returns 201 with user and token", :aggregate_failures do
        post "/api/auth/register", params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        json = response.parsed_body

        expect(json["success"]).to be true
        expect(json["data"]["user"]).to include("email" => "alice@example.com", "name" => "Alice")
        expect(json["data"]["token"]).to be_present
      end

      it "creates a new user in the database" do
        expect {
          post "/api/auth/register", params: valid_params.to_json, headers: headers
        }.to change(User, :count).by(1)
      end

      it "returns a valid JWT token" do
        post "/api/auth/register", params: valid_params.to_json, headers: headers

        token = response.parsed_body.dig("data", "token")
        payload = JwtService.decode(token)
        expect(payload[:user_id]).to eq(User.last.id)
      end
    end

    context "with a duplicate email", :aggregate_failures do
      before { create(:user, email: "alice@example.com") }

      it "returns 422 with errors" do
        post "/api/auth/register", params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["errors"]["email"]).to be_present
      end
    end

    context "with missing fields" do
      it "returns 422 when name is blank", :aggregate_failures do
        params = { user: { email: "alice@example.com", password: "password123" } }
        post "/api/auth/register", params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]["name"]).to be_present
      end

      it "returns 422 when password is too short", :aggregate_failures do
        params = { user: { email: "alice@example.com", name: "Alice", password: "short" } }
        post "/api/auth/register", params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]["password"]).to be_present
      end
    end
  end

  describe "POST /api/auth/login" do
    let!(:user) { create(:user, email: "bob@example.com", password: "password123") }

    context "with valid credentials" do
      it "returns 200 with user and token", :aggregate_failures do
        post "/api/auth/login",
             params: { email: "bob@example.com", password: "password123" }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["success"]).to be true
        expect(json["data"]["user"]["id"]).to eq(user.id)
        expect(json["data"]["token"]).to be_present
      end

      it "is case-insensitive for email" do
        post "/api/auth/login",
             params: { email: "BOB@EXAMPLE.COM", password: "password123" }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context "with wrong password", :aggregate_failures do
      it "returns 401" do
        post "/api/auth/login",
             params: { email: "bob@example.com", password: "wrongpassword" }.to_json,
             headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["errors"]["auth"]).to be_present
      end
    end

    context "with unknown email" do
      it "returns 401", :aggregate_failures do
        post "/api/auth/login",
             params: { email: "nobody@example.com", password: "password123" }.to_json,
             headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
