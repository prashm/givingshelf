class OtpMailer < ApplicationMailer
  def send_otp(user, otp_code)
    @user = user
    @otp_code = otp_code
    @expires_in_minutes = 5

    mail(
      to: @user.email_address,
      subject: "Your GivingShelf verification code"
    )
  end
end
