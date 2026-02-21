# frozen_string_literal: true

class Api::ProjectsController < Api::BaseController
  before_action :set_project, only: %i[show invite]
  before_action :authorize_member!, only: :show
  before_action :authorize_owner!, only: :invite

  def index
    projects = current_user.projects
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 25).to_i
    total = projects.count
    paginated = projects.offset((page - 1) * per_page).limit(per_page)

    render_success(data: {
      projects: paginated.map { |p| project_json(p) },
      pagination: { page: page, per_page: per_page, total: total, pages: (total.to_f / per_page).ceil }
    })
  end

  def create
    project = Project.new(project_params)

    ActiveRecord::Base.transaction do
      project.save!
      project.memberships.create!(user: current_user, role: :owner)
    end

    render_success(data: { project: project_json(project) }, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_error(errors: e.record.errors.to_hash(true), status: :unprocessable_entity)
  end

  def show
    render_success(data: { project: project_detail_json(@project) })
  end

  def invite
    user = User.find_by(email: params.dig(:invite, :email)&.downcase)
    unless user
      return render_error(errors: { email: ["User not found"] }, status: :not_found)
    end

    membership = @project.memberships.new(user: user, role: params.dig(:invite, :role) || :member)

    if membership.save
      render_success(data: { membership: membership_json(membership) }, status: :created)
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

  def authorize_member!
    return if current_user_membership

    render_error(errors: { project: ["Access denied"] }, status: :forbidden)
  end

  def authorize_owner!
    return if current_user_membership&.owner?

    render_error(errors: { project: ["Only the project owner can perform this action"] }, status: :forbidden)
  end

  def current_user_membership
    @current_user_membership ||= @project.memberships.find_by(user: current_user)
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end

  def project_json(project)
    { id: project.id, name: project.name, description: project.description,
      created_at: project.created_at, updated_at: project.updated_at }
  end

  def project_detail_json(project)
    project_json(project).merge(
      members: project.memberships.includes(:user).map { |m| membership_json(m) }
    )
  end

  def membership_json(membership)
    { id: membership.id, user_id: membership.user_id, project_id: membership.project_id,
      role: membership.role, user: { id: membership.user.id, email: membership.user.email, name: membership.user.name } }
  end
end
