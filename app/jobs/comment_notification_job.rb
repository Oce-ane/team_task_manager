# frozen_string_literal: true

class CommentNotificationJob < ApplicationJob
  queue_as :default

  def perform(comment_id)
    comment = Comment.find_by(id: comment_id)
    return unless comment

    task = comment.task
    assignee = task.assignee
    return unless assignee
    return if assignee.id == comment.user_id

    Notification.create!(
      user: assignee,
      notifiable: comment,
      message: "#{comment.user.name} commented on task \"#{task.title}\""
    )
  end
end
