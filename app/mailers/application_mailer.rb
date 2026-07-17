class ApplicationMailer < ActionMailer::Base
  default from: -> { "GivingShelf <#{ApplicationSite.email('noreply')}>" }
  layout "mailer"
end
