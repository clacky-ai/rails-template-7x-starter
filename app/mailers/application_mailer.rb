class ApplicationMailer < ActionMailer::Base
  default from: "notifications@#{ENV.fetch("EMAIL_SMTP_DOMAIN", 'example.com')}"
  layout "mailer"
end
