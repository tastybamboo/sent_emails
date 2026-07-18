# frozen_string_literal: true

require "openssl"

module SentEmails
  module Providers
    # Mailgun webhook provider
    #
    # Mailgun sends webhook notifications for email delivery events. Unlike
    # Postmark and Mailpace, Mailgun embeds the signature inside the JSON
    # body rather than an HTTP header. Configure your webhook URL in the
    # Mailgun dashboard under Sending > Webhooks.
    #
    # @example Configuration
    #   SentEmails.configure do |config|
    #     config.provider :mailgun do |p|
    #       p.signing_key = Rails.application.credentials.dig(:mailgun, :signing_key)
    #     end
    #   end
    #
    # @see https://documentation.mailgun.com/docs/mailgun/user-manual/tracking-messages/#webhooks
    class Mailgun < Base
      # Map Mailgun event types to our normalized types
      # https://documentation.mailgun.com/docs/mailgun/user-manual/tracking-messages/#webhooks
      EVENT_MAP = {
        "accepted" => "sent",
        "delivered" => "delivered",
        "opened" => "opened",
        "clicked" => "clicked",
        "unsubscribed" => "unsubscribed",
        "complained" => "spam"
      }.freeze

      def valid_signature?
        signing_key = provider_config[:signing_key]
        return false if signing_key.blank?

        signature_data = payload["signature"] || {}
        timestamp = signature_data["timestamp"]
        token = signature_data["token"]
        signature = signature_data["signature"]
        return false if timestamp.blank? || token.blank? || signature.blank?

        verify_hmac_signature(signature, signing_key, timestamp, token)
      end

      def events
        event_name = payload.dig("event-data", "event")
        event_type = (event_name == "failed") ? adjust_bounce_type : normalize_event_type(event_name)
        return [] unless event_type

        [{
          message_id: extract_message_id,
          event_type: event_type,
          occurred_at: extract_timestamp,
          payload: payload
        }]
      end

      private

      def provider_config
        SentEmails.provider_config(:mailgun)
      end

      def verify_hmac_signature(signature, signing_key, timestamp, token)
        expected = OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new("sha256"),
          signing_key,
          "#{timestamp}#{token}"
        )

        ActiveSupport::SecurityUtils.secure_compare(signature.downcase, expected.downcase)
      rescue => e
        Rails.logger.warn("[SentEmails::Mailgun] Signature verification failed: #{e.message}")
        false
      end

      def extract_message_id
        payload.dig("event-data", "message", "headers", "message-id")
      end

      def extract_timestamp
        timestamp = payload.dig("event-data", "timestamp")

        Time.at(Float(timestamp))
      rescue TypeError, ArgumentError
        Time.current
      end

      # Mailgun's "failed" event distinguishes bounce severity via
      # event-data.severity rather than a distinct event name, so it can't
      # live in EVENT_MAP alongside the 1:1 mappings.
      def adjust_bounce_type
        case payload.dig("event-data", "severity")
        when "permanent"
          "bounced"
        when "temporary"
          "soft_bounced"
        else
          "deferred"
        end
      end
    end
  end
end
