# frozen_string_literal: true

module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = extract_token
    unless token
      return render_error(errors: { auth: ["Missing token"] }, status: :unauthorized)
    end

    begin
      payload = JwtService.decode(token)
      @current_user = User.find(payload[:user_id])
    rescue JWT::DecodeError
      render_error(errors: { auth: ["Invalid or expired token"] }, status: :unauthorized)
    rescue ActiveRecord::RecordNotFound
      render_error(errors: { auth: ["User not found"] }, status: :unauthorized)
    end
  end

  def current_user
    @current_user
  end

  def extract_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end
end
