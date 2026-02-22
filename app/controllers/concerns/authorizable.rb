# frozen_string_literal: true

module Authorizable
  extend ActiveSupport::Concern

  private

  def current_user_membership
    @current_user_membership ||= @project&.memberships&.find_by(user: current_user)
  end

  def authorize_project_member!
    return if current_user_membership

    render_error(errors: { project: ["Access denied"] }, status: :forbidden)
  end

  def authorize_project_owner!
    return if current_user_membership&.owner?

    render_error(errors: { project: ["Only the project owner can perform this action"] }, status: :forbidden)
  end
end
