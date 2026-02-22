# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Notifications", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  describe "GET /api/notifications" do
    let!(:notif1) { create(:notification, user: user, message: "Notif 1") }
    let!(:notif2) { create(:notification, user: user, message: "Notif 2") }
    let!(:other_notif) { create(:notification, message: "Other user notif") }

    it "returns only the current user's notifications", :aggregate_failures do
      get "/api/notifications", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json["success"]).to be true
      expect(json["data"]["notifications"].size).to eq(2)
    end

    it "returns pagination data", :aggregate_failures do
      get "/api/notifications", headers: headers

      pagination = response.parsed_body["data"]["pagination"]
      expect(pagination["total"]).to eq(2)
      expect(pagination["page"]).to eq(1)
    end

    it "does not include other users' notifications" do
      get "/api/notifications", headers: headers

      ids = response.parsed_body["data"]["notifications"].map { |n| n["id"] }
      expect(ids).not_to include(other_notif.id)
    end

    context "without authentication" do
      it "returns 401" do
        get "/api/notifications"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/notifications/:id/read" do
    let!(:notification) { create(:notification, user: user, read: false) }

    it "marks the notification as read", :aggregate_failures do
      patch "/api/notifications/#{notification.id}/read", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json["success"]).to be true
      expect(json["data"]["notification"]["read"]).to be true
    end

    context "when notification belongs to another user" do
      let!(:other_notif) { create(:notification) }

      it "returns 404" do
        patch "/api/notifications/#{other_notif.id}/read", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when notification does not exist" do
      it "returns 404" do
        patch "/api/notifications/999999/read", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/notifications/read_all" do
    let!(:unread1) { create(:notification, user: user, read: false) }
    let!(:unread2) { create(:notification, user: user, read: false) }
    let!(:already_read) { create(:notification, :read, user: user) }
    let!(:other_user_notif) { create(:notification, read: false) }

    it "marks all current user's unread notifications as read", :aggregate_failures do
      patch "/api/notifications/read_all", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["success"]).to be true

      expect(unread1.reload.read).to be true
      expect(unread2.reload.read).to be true
    end

    it "does not affect other users' notifications" do
      patch "/api/notifications/read_all", headers: headers

      expect(other_user_notif.reload.read).to be false
    end
  end
end
