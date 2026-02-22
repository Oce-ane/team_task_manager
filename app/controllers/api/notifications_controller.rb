# frozen_string_literal: true

class Api::NotificationsController < Api::BaseController
  def index
    notifications = current_user.notifications.order(created_at: :desc)

    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 25).to_i
    total = notifications.count
    paginated = notifications.offset((page - 1) * per_page).limit(per_page)

    render_success(data: {
      notifications: paginated.map { |n| notification_json(n) },
      pagination: { page: page, per_page: per_page, total: total, pages: (total.to_f / per_page).ceil }
    })
  end

  def read
    notification = current_user.notifications.find(params[:id])
    notification.update!(read: true)

    render_success(data: { notification: notification_json(notification) })
  rescue ActiveRecord::RecordNotFound
    render_error(errors: { notification: ["Not found"] }, status: :not_found)
  end

  def read_all
    current_user.notifications.unread.update_all(read: true)

    render_success(data: { message: "All notifications marked as read" })
  end

  private

  def notification_json(notification)
    {
      id: notification.id, message: notification.message, read: notification.read,
      notifiable_type: notification.notifiable_type, notifiable_id: notification.notifiable_id,
      created_at: notification.created_at, updated_at: notification.updated_at
    }
  end
end
