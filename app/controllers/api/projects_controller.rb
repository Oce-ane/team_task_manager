# frozen_string_literal: true

class Api::ProjectsController < Api::BaseController
  include Authorizable

  before_action :set_project, only: %i[show invite]
  before_action :authorize_project_member!, only: :show
  before_action :authorize_project_owner!, only: :invite

  def index
    projects, pagination = paginate(current_user.projects)

    render_success(data: {
      projects: projects.map(&:as_api_json),
      pagination: pagination
    })
  end

  def create
    project = Project.new(project_params)

    ActiveRecord::Base.transaction do
      project.save!
      project.memberships.create!(user: current_user, role: :owner)
    end

    render_success(data: { project: project.as_api_json }, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_error(errors: e.record.errors.to_hash(true), status: :unprocessable_entity)
  end

  def show
    render_success(data: { project: @project.as_api_detail_json })
  end

  def invite
    user = User.find_by(email: params.dig(:invite, :email)&.downcase)
    unless user
      return render_error(errors: { email: ["User not found"] }, status: :not_found)
    end

    membership = @project.memberships.new(user: user, role: params.dig(:invite, :role) || :member)

    if membership.save
      render_success(data: { membership: membership.as_api_json }, status: :created)
    else
      render_error(errors: membership.errors.to_hash(true), status: :unprocessable_entity)
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(errors: { project: ["Not found"] }, status: :not_found)
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
