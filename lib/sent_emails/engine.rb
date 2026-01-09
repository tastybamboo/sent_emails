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

    # Add middleware to capture request context for emails sent from controllers
    initializer "sent_emails.request_context" do |app|
      app.middleware.use SentEmails::RequestMiddleware
    end

    # Hook into ActionMailer to automatically capture all emails
    # Use both to_prepare (for console/runner) and eager_load! (for web server)
    initializer "sent_emails.hook_action_mailer" do |app|
      # Set up to_prepare callback for console/runner/tests
      app.config.to_prepare do
        if defined?(ActionMailer::MessageDelivery) && !ActionMailer::MessageDelivery.ancestors.include?(SentEmails::ActionMailerHook)
          ActionMailer::MessageDelivery.prepend(SentEmails::ActionMailerHook)
        end
      end
      
      # Also try immediately in case we're past that phase
      if defined?(ActionMailer::MessageDelivery) && !ActionMailer::MessageDelivery.ancestors.include?(SentEmails::ActionMailerHook)
        ActionMailer::MessageDelivery.prepend(SentEmails::ActionMailerHook)
      end
    end
  end
end
