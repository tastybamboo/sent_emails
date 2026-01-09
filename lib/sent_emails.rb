# frozen_string_literal: true

require_relative "sent_emails/version"
require_relative "sent_emails/configuration"
require_relative "sent_emails/engine"
require_relative "sent_emails/mailer_helper"
require_relative "sent_emails/capture"
require_relative "sent_emails/request_middleware"
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
  # after they're delivered, including Devise emails and custom mailers.
  #
  # This works by prepending a module that intercepts deliver_now and deliver_later.
  #
  # Note: We can only capture emails in deliver_now because Rails doesn't allow
  # accessing the message before deliver_later (it raises an error). So for
  # deliver_later emails, we capture when the job runs deliver_now.
  module ActionMailerHook
    def deliver_now
      capture_request_context
      result = super
      capture_email
      result
    rescue => e
      # Re-raise the original error but still try to capture
      Rails.logger.error("[SentEmails] Error during deliver_now: #{e.message}")
      raise
    ensure
      clear_request_context
    end

    def deliver_later(*)
      # Note: We cannot capture here because Rails doesn't allow accessing
      # the message before deliver_later. The email will be captured when
      # the job runs deliver_now.
      super
    end

    def capture_request_context
      # Request context is captured via RequestMiddleware if available.
      # The middleware sets Thread.current[:__sent_emails_request] for each request.
    end

    def clear_request_context
      Thread.current[:__sent_emails_request] = nil
    end

    private

    def capture_email
      return unless SentEmails.enabled?

      mail_message = message
      return unless mail_message

      SentEmails::Capture.call(
        message: mail_message,
        mailer: @mailer_class.name,
        action: @action,
        params: extract_mailer_params,
        delivery_method: extract_delivery_method,
        delivery_settings: extract_delivery_settings,
        delivery_type: detect_delivery_type,
        request: extract_request_context,
        status: :sent
      )
    rescue => e
      Rails.logger.error("[SentEmails] Failed to capture email: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
    end

    def extract_mailer_params
      # Mailers using .with() store params in @params (e.g., Devise)
      # Mailers passing args directly store them in @args
      if defined?(@params) && @params.present?
        @params
      elsif @args.is_a?(Array) && @args.first.is_a?(Hash)
        @args.first
      elsif @args.is_a?(Array) && @args.any?
        @args.each_with_index.to_h { |arg, i| ["arg_#{i}".to_sym, arg] }
      else
        {}
      end
    rescue
      {}
    end

    def detect_delivery_type
      # Check if we're being called from a background job
      if caller_locations.any? { |loc| loc.path.to_s.include?("active_job") }
        "deliver_later"
      else
        "deliver_now"
      end
    rescue
      "unknown"
    end

    def extract_request_context
      return nil unless defined?(ActionDispatch::Request)
      Thread.current[:__sent_emails_request]
    rescue
      nil
    end

    def extract_delivery_method
      message.delivery_method.class.name.demodulize.underscore.to_sym
    rescue
      :unknown
    end

    def extract_delivery_settings
      settings = message.delivery_method.settings
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
