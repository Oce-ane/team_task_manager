# frozen_string_literal: true

class Api::BaseController < ApplicationController
  include Authenticable

  private

  def render_success(data:, status: :ok)
    render json: { success: true, data: data }, status: status
  end

  def render_error(errors:, status: :unprocessable_content)
    render json: { success: false, errors: errors }, status: status
  end

  def paginate(scope)
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 25).to_i
    total = scope.count
    records = scope.offset((page - 1) * per_page).limit(per_page)
    pagination = { page: page, per_page: per_page, total: total, pages: (total.to_f / per_page).ceil }
    [ records, pagination ]
  end
end
