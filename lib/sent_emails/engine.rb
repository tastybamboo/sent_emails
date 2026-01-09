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
    initializer "sent_emails.hook_action_mailer", after: :load_config_initializers do
      ActionMailer::MessageDelivery.prepend(SentEmails::ActionMailerHook)
    end
  end
end
