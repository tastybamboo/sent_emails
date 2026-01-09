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

    # Automatically patch ActionMailer to capture emails
    # This hook allows Devise and other mailers to be captured without modification
    initializer "sent_emails.hook_mailer_delivery" do |app|
      require_relative "action_mailer_hook"
      
      app.config.to_prepare do
        ActionMailer::MessageDelivery.prepend(SentEmails::ActionMailerHook)
      end
      
      # Also prepend immediately in case we're already past the to_prepare phase
      ActionMailer::MessageDelivery.prepend(SentEmails::ActionMailerHook) if defined?(ActionMailer::MessageDelivery)
    end
  end
end
