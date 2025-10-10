class ApplicationMailer < ActionMailer::Base
  default from: "from@#{ENV.fetch("EMAIL_SMTP_DOMAIN", 'example.com')}"
  layout "mailer"
end
