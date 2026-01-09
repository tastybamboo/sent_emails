# frozen_string_literal: true

module SentEmails
  class Engine < ::Rails::Engine
    isolate_namespace SentEmails

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "sent_emails.assets" do |app|
      app.config.assets.precompile += %w[sent_emails/application.css] if app.config.respond_to?(:assets)
    end

    # Automatically include MailerHelper in all ActionMailer::Base subclasses
    initializer "sent_emails.include_mailer_helper" do
      ActiveSupport.on_load(:action_mailer) do
        include SentEmails::MailerHelper
      end
    end
  end
end
