# frozen_string_literal: true

class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project

  enum :role, { member: 0, owner: 1 }

  validates :user_id, uniqueness: { scope: :project_id, message: "is already a member of this project" }
  validates :role, presence: true
end
