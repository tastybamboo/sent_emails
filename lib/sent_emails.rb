# frozen_string_literal: true

require_relative "sent_emails/version"
require_relative "sent_emails/configuration"
require_relative "sent_emails/engine"
require_relative "sent_emails/mailer_helper"
require_relative "sent_emails/capture"
require_relative "sent_emails/providers/base"
require_relative "sent_emails/providers/mailpace"
require_relative "sent_emails/test_helpers"

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

  # Automatically patches ActionMailer::MessageDelivery to capture all emails
  # before they're delivered, including Devise emails and custom mailers.
  #
  # This works by prepending a module that intercepts deliver_now and deliver_later.
  module ActionMailerHook
    def deliver_now
      capture_email_before_delivery
      super
    end

    def deliver_later(*)
      capture_email_before_delivery
      super
    end

    private

    def capture_email_before_delivery
      return unless SentEmails.enabled?
      return unless @mail_message

      SentEmails::Capture.call(
        message: @mail_message,
        mailer: @mailer_class.name,
        action: @action,
        params: @args.first || {},
        delivery_method: extract_delivery_method,
        delivery_settings: extract_delivery_settings
      )
    rescue => e
      Rails.logger.error("[SentEmails] Failed to capture email: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
    end

    def extract_delivery_method
      @mail_message.delivery_method.class.name.demodulize.underscore.to_sym
    rescue
      :unknown
    end

    def extract_delivery_settings
      settings = @mail_message.delivery_method.settings
      settings.is_a?(Hash) ? settings : {}
    rescue
      {}
    end
  end

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
