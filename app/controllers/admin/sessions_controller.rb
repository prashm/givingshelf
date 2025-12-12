module Admin
  class SessionsController < ApplicationController
    skip_before_action :require_authentication, only: [ :new, :create ]
    layout "active_admin_logged_out"

    def new
      redirect_to admin_root_path if current_admin_user
    end

    def create
      email = params[:email]&.strip&.downcase
      password = params[:password]

      if email.blank? || password.blank?
        flash.now[:alert] = "Email and password are required."
        render :new, status: :unprocessable_entity
        return
      end

      user = User.authenticate_by(email_address: email, password: password)

      if user && user.admin?
        start_new_session_for(user)
        redirect_to admin_root_path, notice: "Signed in successfully."
      else
        flash.now[:alert] = "Invalid email or password, or you don't have admin access."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      terminate_session
      redirect_to admin_login_path, notice: "Signed out successfully."
    end
  end
end
