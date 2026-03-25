# frozen_string_literal: true

require "openssl"

module SentEmails
  module Providers
    # Postmark webhook provider
    #
    # Postmark sends webhook notifications for email delivery events.
    # Configure your webhook URL in the Postmark dashboard under
    # Servers > [Your Server] > Webhooks.
    #
    # @example Configuration
    #   SentEmails.configure do |config|
    #     config.provider :postmark do |p|
    #       p.webhook_token = Rails.application.credentials.dig(:postmark, :webhook_token)
    #     end
    #   end
    #
    # @see https://postmarkapp.com/developer/webhooks/webhooks-overview
    class Postmark < Base
      # Map Postmark event types to our normalized types
      # https://postmarkapp.com/developer/webhooks/webhooks-overview
      EVENT_MAP = {
        "Delivery" => "delivered",
        "Bounce" => "bounced",
        "SpamComplaint" => "spam",
        "Open" => "opened",
        "Click" => "clicked",
        "SubscriptionChange" => "unsubscribed"
      }.freeze

      # Postmark bounce types that should be treated as soft bounces
      SOFT_BOUNCE_TYPES = %w[
        Transient
        AutoResponder
        AddressChange
        ChallengeVerification
        DnsError
        SpamNotification
        OpenRelayTest
        Blocked
      ].freeze

      def valid_signature?
        signature = headers["X-Postmark-Signature"] || headers["HTTP_X_POSTMARK_SIGNATURE"]
        return false if signature.blank?

        webhook_token = provider_config[:webhook_token]
        return false if webhook_token.blank?

        verify_hmac_signature(signature, webhook_token)
      end

      def events
        event_type = normalize_event_type(payload["RecordType"])
        return [] unless event_type

        # Adjust event type for soft bounces
        adjusted_event_type = adjust_bounce_type(event_type)

        [{
          message_id: extract_message_id,
          event_type: adjusted_event_type,
          occurred_at: extract_timestamp,
          payload: payload
        }]
      end

      private

      def provider_config
        SentEmails.provider_config(:postmark)
      end

      def verify_hmac_signature(signature, webhook_token)
        expected = OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new("sha256"),
          webhook_token,
          raw_body
        )

        ActiveSupport::SecurityUtils.secure_compare(signature.downcase, expected.downcase)
      rescue => e
        Rails.logger.warn("[SentEmails::Postmark] Signature verification failed: #{e.message}")
        false
      end

      def extract_message_id
        # Postmark includes the Message-ID in several places depending on event type
        payload["MessageID"] ||
          payload.dig("Metadata", "message_id") ||
          extract_message_id_from_headers
      end

      def extract_message_id_from_headers
        # Some events include the original email headers
        headers_array = payload["Headers"] || []
        message_id_header = headers_array.find { |h| h["Name"]&.casecmp("Message-ID")&.zero? }
        message_id_header&.dig("Value")
      end

      def extract_timestamp
        # Postmark uses different timestamp fields depending on event type
        timestamp = payload["DeliveredAt"] ||
          payload["BouncedAt"] ||
          payload["ReceivedAt"] ||
          payload["Timestamp"]

        timestamp ? Time.parse(timestamp) : Time.current
      rescue ArgumentError
        Time.current
      end

      def adjust_bounce_type(event_type)
        return event_type unless event_type == "bounced"

        # Check if this is a soft bounce based on Postmark's TypeCode or Type
        bounce_type = payload["Type"]
        type_code = payload["TypeCode"]

        # TypeCode >= 400 and < 500 are soft bounces in Postmark
        if type_code && type_code >= 400 && type_code < 500
          return "soft_bounced"
        end

        # Also check the Type field for known soft bounce types
        if bounce_type && SOFT_BOUNCE_TYPES.include?(bounce_type)
          return "soft_bounced"
        end

        event_type
      end
    end
  end
end
