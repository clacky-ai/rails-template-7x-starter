class ApplicationMailer < ActionMailer::Base
  default from: "#{(Rails.application.config.x.appname.presence || 'ClackyAI')} <notifications@#{ENV.fetch("EMAIL_SMTP_DOMAIN", 'example.com')}>"
  layout "mailer"
end
