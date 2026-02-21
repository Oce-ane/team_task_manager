# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Projects", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  describe "GET /api/projects" do
    context "when authenticated" do
      let!(:owned_project) { create(:project, name: "My Project") }
      let!(:member_project) { create(:project, name: "Team Project") }
      let!(:other_project) { create(:project, name: "Other Project") }

      before do
        create(:membership, :owner, user: user, project: owned_project)
        create(:membership, user: user, project: member_project)
        # other_project has no membership for user
      end

      it "returns only projects the user is a member of", :aggregate_failures do
        get "/api/projects", headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["success"]).to be true
        project_names = json["data"]["projects"].map { |p| p["name"] }
        expect(project_names).to contain_exactly("My Project", "Team Project")
        expect(project_names).not_to include("Other Project")
      end

      it "returns pagination data", :aggregate_failures do
        get "/api/projects", headers: headers

        json = response.parsed_body
        pagination = json["data"]["pagination"]

        expect(pagination["page"]).to eq(1)
        expect(pagination["per_page"]).to eq(25)
        expect(pagination["total"]).to eq(2)
        expect(pagination["pages"]).to eq(1)
      end

      it "respects page and per_page params", :aggregate_failures do
        get "/api/projects", params: { page: 1, per_page: 1 }, headers: headers

        json = response.parsed_body
        expect(json["data"]["projects"].size).to eq(1)
        expect(json["data"]["pagination"]["pages"]).to eq(2)
      end
    end

    context "without authentication" do
      it "returns 401" do
        get "/api/projects"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/projects" do
    let(:valid_params) { { project: { name: "New Project", description: "A great project" } } }

    context "with valid params" do
      it "creates a project and returns 201", :aggregate_failures do
        post "/api/projects", params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        json = response.parsed_body

        expect(json["success"]).to be true
        expect(json["data"]["project"]["name"]).to eq("New Project")
        expect(json["data"]["project"]["description"]).to eq("A great project")
      end

      it "creates the project in the database" do
        expect {
          post "/api/projects", params: valid_params.to_json, headers: headers
        }.to change(Project, :count).by(1)
      end

      it "creates an owner membership for the current user", :aggregate_failures do
        post "/api/projects", params: valid_params.to_json, headers: headers

        project = Project.last
        membership = project.memberships.find_by(user: user)

        expect(membership).to be_present
        expect(membership.role).to eq("owner")
      end
    end

    context "with missing name" do
      it "returns 422 with errors", :aggregate_failures do
        post "/api/projects", params: { project: { description: "No name" } }.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body

        expect(json["success"]).to be false
        expect(json["errors"]["name"]).to be_present
      end
    end

    context "without authentication" do
      it "returns 401" do
        post "/api/projects", params: valid_params.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/projects/:id" do
    let(:project) { create(:project, name: "Show Project") }

    context "when user is a member" do
      before { create(:membership, :owner, user: user, project: project) }

      it "returns the project with members", :aggregate_failures do
        get "/api/projects/#{project.id}", headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["success"]).to be true
        expect(json["data"]["project"]["name"]).to eq("Show Project")
        expect(json["data"]["project"]["members"]).to be_an(Array)
        expect(json["data"]["project"]["members"].first["user"]["email"]).to eq(user.email)
      end
    end

    context "when user is not a member" do
      it "returns 403", :aggregate_failures do
        get "/api/projects/#{project.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body["success"]).to be false
      end
    end

    context "when project does not exist" do
      it "returns 404" do
        get "/api/projects/999999", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/projects/:id/invite" do
    let(:project) { create(:project) }
    let(:invitee) { create(:user, email: "invitee@example.com") }

    context "when user is the owner" do
      before { create(:membership, :owner, user: user, project: project) }

      it "invites a user by email and returns 201", :aggregate_failures do
        params = { invite: { email: invitee.email, role: "member" } }
        post "/api/projects/#{project.id}/invite", params: params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        json = response.parsed_body

        expect(json["success"]).to be true
        expect(json["data"]["membership"]["user_id"]).to eq(invitee.id)
        expect(json["data"]["membership"]["role"]).to eq("member")
      end

      it "creates a membership in the database" do
        params = { invite: { email: invitee.email } }

        expect {
          post "/api/projects/#{project.id}/invite", params: params.to_json, headers: headers
        }.to change(Membership, :count).by(1)
      end

      it "defaults role to member when not specified", :aggregate_failures do
        params = { invite: { email: invitee.email } }
        post "/api/projects/#{project.id}/invite", params: params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["data"]["membership"]["role"]).to eq("member")
      end

      it "returns 404 when invitee email is not found", :aggregate_failures do
        params = { invite: { email: "nobody@example.com" } }
        post "/api/projects/#{project.id}/invite", params: params.to_json, headers: headers

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["errors"]["email"]).to include("User not found")
      end

      it "returns 422 when user is already a member", :aggregate_failures do
        create(:membership, user: invitee, project: project)

        params = { invite: { email: invitee.email } }
        post "/api/projects/#{project.id}/invite", params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["success"]).to be false
      end
    end

    context "when user is a member but not owner" do
      before { create(:membership, user: user, project: project) }

      it "returns 403", :aggregate_failures do
        params = { invite: { email: invitee.email } }
        post "/api/projects/#{project.id}/invite", params: params.to_json, headers: headers

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body["success"]).to be false
      end
    end

    context "when user is not a project member at all" do
      it "returns 403" do
        params = { invite: { email: invitee.email } }
        post "/api/projects/#{project.id}/invite", params: params.to_json, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
