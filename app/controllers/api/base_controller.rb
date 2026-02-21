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
end
