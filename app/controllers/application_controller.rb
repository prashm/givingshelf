class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # ActiveAdmin authentication methods
  def authenticate_admin_user!
    # Ensure session is resumed for ActiveAdmin controllers
    resume_session unless Current.session
    unless current_admin_user
      redirect_to admin_login_path, alert: "You need to sign in to continue."
    end
  end

  def current_admin_user
    # Ensure session is resumed
    resume_session unless Current.session
    return nil unless Current.user
    return nil unless Current.user.admin?
    Current.user
  end

  def redirect_to_admin_login
    redirect_to admin_login_path, alert: "You need to sign in to continue."
  end
end
