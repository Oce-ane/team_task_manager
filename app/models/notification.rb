# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true

  validates :message, presence: true

  scope :unread, -> { where(read: false) }

  def as_api_json
    {
      id: id, message: message, read: read,
      notifiable_type: notifiable_type, notifiable_id: notifiable_id,
      created_at: created_at, updated_at: updated_at
    }
  end
end
