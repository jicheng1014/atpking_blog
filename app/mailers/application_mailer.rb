class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM") { ENV.fetch("SMTP_USER_NAME", "from@example.com") } }
  layout "mailer"
end
