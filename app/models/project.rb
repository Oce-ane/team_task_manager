# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :tasks, dependent: :destroy

  validates :name, presence: true

  def as_api_json
    { id: id, name: name, description: description, created_at: created_at, updated_at: updated_at }
  end

  def as_api_detail_json
    as_api_json.merge(members: memberships.includes(:user).map(&:as_api_json))
  end
end
