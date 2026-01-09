class PasswordsController < ApplicationController
  allow_unauthenticated_access
  layout "admin"

  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user, params[:return_to]).deliver_later
    end

    redirect_to redirect_path,
      notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
    @return_to = params[:return_to]
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      redirect_to redirect_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token], return_to: params[:return_to]),
        alert: @user.errors.full_messages.to_sentence
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path(return_to: params[:return_to]),
      alert: "Password reset link is invalid or has expired."
  end

  def redirect_path
    if params[:return_to] == "group_admin"
      group_admin_login_path
    else
      new_session_path
    end
  end
end
