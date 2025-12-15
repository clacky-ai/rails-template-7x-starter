class ApplicationMailer < ActionMailer::Base
  default from: "#{Rails.application.config.x.appname} <notifications@#{ENV.fetch("EMAIL_SMTP_DOMAIN", 'example.com')}>"
  layout "mailer"
end
