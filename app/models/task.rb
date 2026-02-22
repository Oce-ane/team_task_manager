# frozen_string_literal: true

class Task < ApplicationRecord
  belongs_to :project
  belongs_to :assignee, class_name: "User", optional: true

  has_many :comments, dependent: :destroy

  enum :status, { todo: 0, in_progress: 1, done: 2 }
  enum :priority, { low: 0, medium: 1, high: 2 }

  validates :title, presence: true

  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_assignee, ->(assignee_id) { where(assignee_id: assignee_id) }

  def as_api_json
    {
      id: id, project_id: project_id, title: title, description: description,
      status: status, priority: priority, due_date: due_date, assignee_id: assignee_id,
      assignee: assignee&.as_api_json, created_at: created_at, updated_at: updated_at
    }
  end
end
