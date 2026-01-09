# frozen_string_literal: true

SentEmails.configure do |config|
  # Enable/disable email capture (default: true)
  # config.enabled = true

  # Primary key type for email records (default: :bigint)
  # Use :uuid for UUID primary keys (requires database support)
  # This must be set BEFORE running migrations
  # config.primary_key_type = :bigint

  # Attachment storage strategy
  # Options: :database (store in blob column), :metadata_only (store only metadata)
  # config.attachment_storage = :database

  # Maximum attachment size to store in database (bytes)
  # Attachments larger than this will only have metadata stored
  # config.max_attachment_size = 10.megabytes

  # Retention period for emails (used by cleanup rake task)
  # config.retention_period = 90.days

  # Authentication for the UI
  # Pass a proc or lambda that will be called with the controller instance
  # Example with Devise:
  #   config.authentication_method = ->(controller) { controller.authenticate_admin! }
  # Example with basic auth:
  #   config.authentication_method = ->(controller) {
  #     controller.authenticate_or_request_with_http_basic do |username, password|
  #       username == "admin" && password == "secret"
  #     end
  #   }
  # config.authentication_method = nil

  # Webhook route mounting
  # By default, webhooks are mounted within the engine (e.g., /admin/sent_emails/webhooks/:provider)
  # Set to false to mount webhooks at a separate path using SentEmails.mount_webhook_routes
  #
  # Example for separate webhook path:
  #   config.mount_webhooks_in_engine = false
  #
  #   # Then in config/routes.rb:
  #   mount SentEmails::Engine, at: "/admin/sent_emails"
  #   SentEmails.mount_webhook_routes(self, at: "/webhooks/sent_emails")
  #
  # config.mount_webhooks_in_engine = true

  # Configure webhook providers
  # Each provider has its own authentication mechanism

  # Mailpace uses Ed25519 signatures
  # Get your public key from: https://app.mailpace.com/organizations/YOUR_ORG/webhooks
  # config.provider :mailpace do |p|
  #   p.public_key = Rails.application.credentials.dig(:mailpace, :webhook_public_key)
  # end

  # SendGrid uses a verification key
  # config.provider :sendgrid do |p|
  #   p.verification_key = ENV["SENDGRID_WEBHOOK_VERIFICATION_KEY"]
  # end

  # Postmark uses a webhook token
  # config.provider :postmark do |p|
  #   p.webhook_token = Rails.application.credentials.dig(:postmark, :webhook_token)
  # end
end
