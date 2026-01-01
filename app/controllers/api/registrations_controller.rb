class Api::RegistrationsController < ApplicationController
  skip_before_action :require_authentication

  def create
    user = User.new(user_params)

    if user.save
      # Note: auto_join_groups_by_domain! is called via after_create callback
      start_new_session_for(user)
      render json: {
        user: user_json(user),
        message: "Account created successfully"
      }, status: :created
    else
      render json: {
        error: "Registration failed",
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email_address, :zip_code, :phone, :password, :password_confirmation)
  end

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
