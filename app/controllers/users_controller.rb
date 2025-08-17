class UsersController < ApplicationController
  allow_unauthenticated_access only: [:new, :create]

  def new
  end

  def create
    @user = User.new(user_params)
    
    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Account created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :first_name, :last_name, :zip_code, :phone)
  end
end 