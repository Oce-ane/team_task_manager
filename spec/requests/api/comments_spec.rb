# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Comments", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project) }
  let(:task) { create(:task, project: project, assignee: assignee) }
  let(:assignee) { create(:user) }

  before do
    create(:membership, :owner, user: user, project: project)
    create(:membership, user: assignee, project: project)
  end

  describe "GET /api/tasks/:task_id/comments" do
    let!(:comment1) { create(:comment, task: task, user: user, content: "First") }
    let!(:comment2) { create(:comment, task: task, user: assignee, content: "Second") }

    it "returns all comments for the task", :aggregate_failures do
      get "/api/tasks/#{task.id}/comments", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json["success"]).to be true
      expect(json["data"]["comments"].size).to eq(2)
      expect(json["data"]["comments"].first["content"]).to eq("First")
    end

    it "includes user info with each comment" do
      get "/api/tasks/#{task.id}/comments", headers: headers

      comment = response.parsed_body["data"]["comments"].first
      expect(comment["user"]).to include("id" => user.id, "email" => user.email, "name" => user.name)
    end

    context "when user is not a project member" do
      let(:outsider) { create(:user) }
      let(:outsider_headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{JwtService.encode(user_id: outsider.id)}" } }

      it "returns 403" do
        get "/api/tasks/#{task.id}/comments", headers: outsider_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when task does not exist" do
      it "returns 404" do
        get "/api/tasks/999999/comments", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/tasks/:task_id/comments" do
    let(:valid_params) { { comment: { content: "Great work!" } } }

    context "with valid params" do
      it "creates a comment and returns 201", :aggregate_failures do
        post "/api/tasks/#{task.id}/comments", params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        json = response.parsed_body

        expect(json["success"]).to be true
        expect(json["data"]["comment"]["content"]).to eq("Great work!")
        expect(json["data"]["comment"]["user"]["id"]).to eq(user.id)
      end

      it "creates the comment in the database" do
        expect {
          post "/api/tasks/#{task.id}/comments", params: valid_params.to_json, headers: headers
        }.to change(Comment, :count).by(1)
      end

      it "enqueues a CommentNotificationJob" do
        expect {
          post "/api/tasks/#{task.id}/comments", params: valid_params.to_json, headers: headers
        }.to have_enqueued_job(CommentNotificationJob)
      end
    end

    context "with blank content" do
      it "returns 422", :aggregate_failures do
        params = { comment: { content: "" } }
        post "/api/tasks/#{task.id}/comments", params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]["content"]).to be_present
      end
    end

    context "when user is not a project member" do
      let(:outsider) { create(:user) }
      let(:outsider_headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{JwtService.encode(user_id: outsider.id)}" } }

      it "returns 403" do
        post "/api/tasks/#{task.id}/comments", params: valid_params.to_json, headers: outsider_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/comments/:id" do
    let!(:comment) { create(:comment, task: task, user: user, content: "Original") }

    context "when user is the comment author" do
      it "updates the comment", :aggregate_failures do
        params = { comment: { content: "Updated" } }
        patch "/api/comments/#{comment.id}", params: params.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]["comment"]["content"]).to eq("Updated")
      end
    end

    context "when user is not the comment author" do
      let(:other_member) { create(:user) }
      let(:other_headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{JwtService.encode(user_id: other_member.id)}" } }

      before { create(:membership, user: other_member, project: project) }

      it "returns 403", :aggregate_failures do
        params = { comment: { content: "Nope" } }
        patch "/api/comments/#{comment.id}", params: params.to_json, headers: other_headers

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body["errors"]["comment"]).to be_present
      end
    end

    context "when comment does not exist" do
      it "returns 404" do
        params = { comment: { content: "Ghost" } }
        patch "/api/comments/999999", params: params.to_json, headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/comments/:id" do
    let!(:comment) { create(:comment, task: task, user: user) }

    context "when user is the comment author" do
      it "deletes the comment", :aggregate_failures do
        expect {
          delete "/api/comments/#{comment.id}", headers: headers
        }.to change(Comment, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["success"]).to be true
      end
    end

    context "when user is not the comment author" do
      let(:other_member) { create(:user) }
      let(:other_headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{JwtService.encode(user_id: other_member.id)}" } }

      before { create(:membership, user: other_member, project: project) }

      it "returns 403" do
        delete "/api/comments/#{comment.id}", headers: other_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
