# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :task
  belongs_to :user

  validates :content, presence: true

  def as_api_json
    {
      id: id, task_id: task_id, content: content,
      created_at: created_at, updated_at: updated_at, user: user.as_api_json
    }
  end
end
