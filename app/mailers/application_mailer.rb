class ApplicationMailer < ActionMailer::Base
  default from: "from@#{ENV.fetch("SMTP_DOMAIN")}"
  layout "mailer"
end
