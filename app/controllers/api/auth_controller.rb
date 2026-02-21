# frozen_string_literal: true

class Api::AuthController < Api::BaseController
  skip_before_action :authenticate_user!

  def register
    user = User.new(register_params)

    if user.save
      render_success(data: auth_response(user), status: :created)
    else
      render_error(errors: user.errors.to_hash(true), status: :unprocessable_entity)
    end
  end

  def login
    user = User.find_by(email: params[:email]&.downcase)

    if user&.authenticate(params[:password])
      render_success(data: auth_response(user))
    else
      render_error(errors: { auth: ["Invalid email or password"] }, status: :unauthorized)
    end
  end

  private

  def register_params
    params.require(:user).permit(:email, :password, :name)
  end

  def auth_response(user)
    {
      user: { id: user.id, email: user.email, name: user.name },
      token: JwtService.encode({ user_id: user.id })
    }
  end
end
