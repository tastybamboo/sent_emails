# frozen_string_literal: true

require_relative "sent_emails/version"
require_relative "sent_emails/configuration"
require_relative "sent_emails/engine"
require_relative "sent_emails/mailer_helper"
require_relative "sent_emails/capture"
require_relative "sent_emails/providers/base"
require_relative "sent_emails/providers/mailpace"
require_relative "sent_emails/test_helpers"

# Note: action_mailer_hook is loaded by the engine initializer after ActionMailer is available

# SentEmails is a Rails engine that captures sent emails with full content,
# tracks delivery status via webhooks, and provides an admin UI for viewing
# and resending emails.
#
# @example Basic configuration
#   SentEmails.configure do |config|
#     config.authentication_method = ->(controller) { controller.authenticate_admin! }
#     config.provider :mailpace do |p|
#       p.public_key = Rails.application.credentials.dig(:mailpace, :webhook_public_key)
#     end
#   end
module SentEmails
  class Error < StandardError; end

  class << self
    # Get the current configuration
    # @return [Configuration] The configuration object
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure SentEmails
    # @yield [Configuration] The configuration object
    # @example
    #   SentEmails.configure do |config|
    #     config.enabled = true
    #     config.authentication_method = ->(controller) { controller.authenticate_admin! }
    #   end
    def configure
      yield(configuration)
    end

    # Check if email capture is enabled
    # @return [Boolean] True if enabled, false otherwise
    def enabled?
      configuration.enabled
    end

    # Get provider-specific configuration
    # @param provider_name [String, Symbol] The provider name (e.g., :mailpace)
    # @return [Hash] Provider configuration or empty hash if not configured
    def provider_config(provider_name)
      configuration.providers[provider_name.to_sym] || {}
    end

    # Get the primary key type for database tables
    # @return [Symbol] The primary key type (:bigint or :uuid)
    def primary_key_type
      configuration.primary_key_type
    end
  end
end
