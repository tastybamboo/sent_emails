# frozen_string_literal: true

class TestMailer < ActionMailer::Base
  include SentEmails::MailerHelper

  default from: "test@example.com"

  def welcome_email(user_email)
    @user_email = user_email
    mail(to: user_email, subject: "Welcome!")
  end

  def notification_email(user_email, message)
    @user_email = user_email
    @message = message
    mail(to: user_email, subject: "Notification: #{message}")
  end
end
