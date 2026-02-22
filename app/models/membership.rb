# frozen_string_literal: true

class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project

  enum :role, { member: 0, owner: 1 }

  validates :user_id, uniqueness: { scope: :project_id, message: "is already a member of this project" }
  validates :role, presence: true

  def as_api_json
    { id: id, user_id: user_id, project_id: project_id, role: role, user: user.as_api_json }
  end
end
