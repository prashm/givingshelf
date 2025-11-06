class OtpMailer < ApplicationMailer
  default from: "BookShare Community <noreply@bookshare.com>"

  def send_otp(user, otp_code)
    @user = user
    @otp_code = otp_code
    @expires_in_minutes = 5
    
    mail(
      to: @user.email_address,
      subject: "Your BookShare Community verification code"
    )
  end
end

