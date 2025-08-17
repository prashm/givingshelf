class Api::SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [:create]

  def create
    user = User.find_by(email_address: params[:email])
    
    if user&.authenticate(params[:password])
      start_new_session_for(user)
      render json: {
        user: user_json(user),
        message: "Logged in successfully"
      }
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def destroy
    terminate_session
    render json: { message: "Logged out successfully" }
  end

  private

  def user_json(user)
    {
      id: user.id,
      email_address: user.email_address,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      display_name: user.display_name,
      zip_code: user.zip_code,
      phone: user.phone,
      verified: user.verified?,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end
end 