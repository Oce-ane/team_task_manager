# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user

  validates :name, presence: true
end
