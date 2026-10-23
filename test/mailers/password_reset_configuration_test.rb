require "test_helper"

class PasswordResetConfigurationTest < ActionMailer::TestCase
  test "password reset uses configured sender and public HTTPS URL" do
    previous = ENV["MAIL_FROM"]
    ENV["MAIL_FROM"] = "blog@mail.okuptime.com"
    user = User.new(email_address: "reader@example.com", password: "password123")
    user.save!
    mail = PasswordsMailer.reset(user)
    assert_equal [ "blog@mail.okuptime.com" ], mail.from
    assert_equal [ user.email_address ], mail.to
    assert_includes mail.html_part.body.to_s, "/passwords/"
  ensure
    ENV["MAIL_FROM"] = previous
  end
end
