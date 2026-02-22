# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Tasks", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project) }

  before { create(:membership, :owner, user: user, project: project) }

  describe "GET /api/projects/:project_id/tasks" do
    let!(:todo_task) { create(:task, project: project, status: :todo, priority: :low) }
    let!(:done_task) { create(:task, :done, project: project, priority: :high) }
    let!(:assigned_task) { create(:task, project: project, assignee: user) }

    it "returns all tasks for the project", :aggregate_failures do
      get "/api/projects/#{project.id}/tasks", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json["success"]).to be true
      expect(json["data"]["tasks"].size).to eq(3)
    end

    it "returns pagination data", :aggregate_failures do
      get "/api/projects/#{project.id}/tasks", headers: headers

      pagination = response.parsed_body["data"]["pagination"]
      expect(pagination["total"]).to eq(3)
      expect(pagination["page"]).to eq(1)
    end

    context "with filters" do
      it "filters by status", :aggregate_failures do
        get "/api/projects/#{project.id}/tasks", params: { status: "done" }, headers: headers

        tasks = response.parsed_body["data"]["tasks"]
        expect(tasks.size).to eq(1)
        expect(tasks.first["status"]).to eq("done")
      end

      it "filters by priority", :aggregate_failures do
        get "/api/projects/#{project.id}/tasks", params: { priority: "high" }, headers: headers

        tasks = response.parsed_body["data"]["tasks"]
        expect(tasks.size).to eq(1)
        expect(tasks.first["priority"]).to eq("high")
      end

      it "filters by assignee_id" do
        get "/api/projects/#{project.id}/tasks", params: { assignee_id: user.id }, headers: headers

        tasks = response.parsed_body["data"]["tasks"]
        expect(tasks.size).to eq(1)
        expect(tasks.first["assignee_id"]).to eq(user.id)
      end
    end

    context "when user is not a project member" do
      let(:outsider) { create(:user) }
      let(:outsider_token) { JwtService.encode(user_id: outsider.id) }
      let(:outsider_headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{outsider_token}" } }

      it "returns 403" do
        get "/api/projects/#{project.id}/tasks", headers: outsider_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when project does not exist" do
      it "returns 404" do
        get "/api/projects/999999/tasks", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/projects/:project_id/tasks" do
    let(:valid_params) do
      { task: { title: "New Task", description: "Do something", priority: "high", due_date: "2026-03-01" } }
    end

    context "with valid params" do
      it "creates a task and returns 201", :aggregate_failures do
        post "/api/projects/#{project.id}/tasks", params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        json = response.parsed_body

        expect(json["success"]).to be true
        expect(json["data"]["task"]["title"]).to eq("New Task")
        expect(json["data"]["task"]["priority"]).to eq("high")
        expect(json["data"]["task"]["status"]).to eq("todo")
      end

      it "creates the task in the database" do
        expect {
          post "/api/projects/#{project.id}/tasks", params: valid_params.to_json, headers: headers
        }.to change(Task, :count).by(1)
      end
    end

    context "with an assignee who is a project member" do
      it "assigns the task", :aggregate_failures do
        params = { task: { title: "Assigned Task", assignee_id: user.id } }
        post "/api/projects/#{project.id}/tasks", params: params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["data"]["task"]["assignee_id"]).to eq(user.id)
        expect(response.parsed_body["data"]["task"]["assignee"]["email"]).to eq(user.email)
      end
    end

    context "with an assignee who is not a project member" do
      let(:non_member) { create(:user) }

      it "returns 422", :aggregate_failures do
        params = { task: { title: "Bad Assign", assignee_id: non_member.id } }
        post "/api/projects/#{project.id}/tasks", params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]["assignee"]).to be_present
      end
    end

    context "with missing title" do
      it "returns 422", :aggregate_failures do
        params = { task: { description: "No title" } }
        post "/api/projects/#{project.id}/tasks", params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]["title"]).to be_present
      end
    end

    context "when user is not a project member" do
      let(:outsider) { create(:user) }
      let(:outsider_token) { JwtService.encode(user_id: outsider.id) }
      let(:outsider_headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{outsider_token}" } }

      it "returns 403" do
        post "/api/projects/#{project.id}/tasks", params: valid_params.to_json, headers: outsider_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/tasks/:id" do
    let!(:task) { create(:task, project: project, title: "Original", status: :todo) }

    context "when user is a project member" do
      it "updates the task and returns 200", :aggregate_failures do
        params = { task: { title: "Updated", status: "in_progress" } }
        patch "/api/tasks/#{task.id}", params: params.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["success"]).to be true
        expect(json["data"]["task"]["title"]).to eq("Updated")
        expect(json["data"]["task"]["status"]).to eq("in_progress")
      end

      it "updates assignee to a project member", :aggregate_failures do
        member = create(:user)
        create(:membership, user: member, project: project)

        params = { task: { assignee_id: member.id } }
        patch "/api/tasks/#{task.id}", params: params.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]["task"]["assignee_id"]).to eq(member.id)
      end

      it "rejects assignee who is not a project member", :aggregate_failures do
        non_member = create(:user)

        params = { task: { assignee_id: non_member.id } }
        patch "/api/tasks/#{task.id}", params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]["assignee"]).to be_present
      end
    end

    context "when user is not a project member" do
      let(:outsider) { create(:user) }
      let(:outsider_token) { JwtService.encode(user_id: outsider.id) }
      let(:outsider_headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{outsider_token}" } }

      it "returns 403" do
        params = { task: { title: "Nope" } }
        patch "/api/tasks/#{task.id}", params: params.to_json, headers: outsider_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when task does not exist" do
      it "returns 404" do
        params = { task: { title: "Ghost" } }
        patch "/api/tasks/999999", params: params.to_json, headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/tasks/:id" do
    let!(:task) { create(:task, project: project) }

    context "when user is a project member" do
      it "deletes the task and returns 200", :aggregate_failures do
        expect {
          delete "/api/tasks/#{task.id}", headers: headers
        }.to change(Task, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["success"]).to be true
      end
    end

    context "when user is not a project member" do
      let(:outsider) { create(:user) }
      let(:outsider_token) { JwtService.encode(user_id: outsider.id) }
      let(:outsider_headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{outsider_token}" } }

      it "returns 403" do
        delete "/api/tasks/#{task.id}", headers: outsider_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when task does not exist" do
      it "returns 404" do
        delete "/api/tasks/999999", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
