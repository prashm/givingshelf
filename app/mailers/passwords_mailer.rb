class PasswordsMailer < ApplicationMailer
  def reset(user, return_to = nil)
    @user = user
    @return_to = return_to
    mail subject: "Reset your password", to: user.email_address
  end
end
