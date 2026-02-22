# frozen_string_literal: true

class Api::NotificationsController < Api::BaseController
  def index
    notifications = current_user.notifications.order(created_at: :desc)
    paginated, pagination = paginate(notifications)

    render_success(data: {
      notifications: paginated.map(&:as_api_json),
      pagination: pagination
    })
  end

  def read
    notification = current_user.notifications.find(params[:id])
    notification.update!(read: true)

    render_success(data: { notification: notification.as_api_json })
  rescue ActiveRecord::RecordNotFound
    render_error(errors: { notification: ["Not found"] }, status: :not_found)
  end

  def read_all
    current_user.notifications.unread.update_all(read: true)

    render_success(data: { message: "All notifications marked as read" })
  end
end
