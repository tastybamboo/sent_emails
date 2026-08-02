# frozen_string_literal: true

require "openssl"
require "base64"
require "digest"
require "json"

module SentEmails
  module Providers
    # SendGrid Event Webhook provider
    #
    # SendGrid posts a JSON array of delivery/engagement events and (when
    # Signed Event Webhook is enabled) signs the raw body with ECDSA P-256.
    # Configure your webhook URL in the SendGrid dashboard under Settings >
    # Mail Settings > Event Webhooks.
    #
    # @example Configuration
    #   SentEmails.configure do |config|
    #     config.provider :sendgrid do |p|
    #       p.verification_key = Rails.application.credentials.dig(:sendgrid, :webhook_verification_key)
    #     end
    #   end
    #
    # @see https://www.twilio.com/docs/sendgrid/for-developers/tracking-events/event
    # @see https://www.twilio.com/docs/sendgrid/for-developers/tracking-events/getting-started-event-webhook-security-features
    class Sendgrid < Base
      SIGNATURE_HEADER = "X-Twilio-Email-Event-Webhook-Signature"
      TIMESTAMP_HEADER = "X-Twilio-Email-Event-Webhook-Timestamp"

      # Map SendGrid event types to our normalized types
      # https://www.twilio.com/docs/sendgrid/for-developers/tracking-events/event
      EVENT_MAP = {
        "processed" => "sent",
        "deferred" => "deferred",
        "delivered" => "delivered",
        "bounce" => "bounced",
        "dropped" => "rejected",
        "open" => "opened",
        "click" => "clicked",
        "spamreport" => "spam",
        "unsubscribe" => "unsubscribed",
        "group_unsubscribe" => "unsubscribed"
      }.freeze

      def valid_signature?
        signature = header_value(SIGNATURE_HEADER)
        timestamp = header_value(TIMESTAMP_HEADER)
        return false if signature.blank? || timestamp.blank? || raw_body.blank?

        verification_key = provider_config[:verification_key]
        return false if verification_key.blank?

        verify_ecdsa_signature(signature, timestamp, verification_key)
      end

      def events
        event_list.filter_map do |event|
          next unless event.is_a?(Hash)

          event = event.with_indifferent_access
          event_type = normalize_event_type(event["event"])
          next unless event_type

          event_type = adjust_bounce_type(event_type, event)

          {
            message_id: extract_message_id(event),
            event_type: event_type,
            occurred_at: extract_timestamp(event),
            payload: event
          }
        end
      end

      private

      def provider_config
        SentEmails.provider_config(:sendgrid)
      end

      def header_value(name)
        headers[name] || headers["HTTP_#{name.tr("-", "_").upcase}"]
      end

      # SendGrid delivers a JSON array. Rails wraps arrays under `_json` when
      # parsing request parameters; prefer that, then fall back to the raw body.
      def event_list
        if payload["_json"].is_a?(Array)
          payload["_json"]
        else
          parsed = JSON.parse(raw_body.to_s)
          parsed.is_a?(Array) ? parsed : Array.wrap(parsed)
        end
      rescue JSON::ParserError
        []
      end

      def verify_ecdsa_signature(signature, timestamp, verification_key)
        public_key = convert_public_key(verification_key)
        payload_digest = Digest::SHA256.digest("#{timestamp}#{raw_body}")
        decoded_signature = Base64.decode64(signature)

        public_key.dsa_verify_asn1(payload_digest, decoded_signature)
      rescue => e
        Rails.logger.warn("[SentEmails::Sendgrid] Signature verification failed: #{e.message}")
        false
      end

      # The verification key from SendGrid is a Base64-encoded PEM/DER public key.
      def convert_public_key(verification_key)
        OpenSSL::PKey::EC.new(Base64.decode64(verification_key))
      end

      def extract_message_id(event)
        smtp_id = event["smtp-id"].presence || event["smtp_id"].presence
        if smtp_id
          return smtp_id.to_s.delete_prefix("<").delete_suffix(">")
        end

        event["message_id"].presence ||
          event.dig("unique_args", "message_id").presence ||
          event.dig("custom_args", "message_id").presence
      end

      def extract_timestamp(event)
        timestamp = event["timestamp"]
        return Time.current if timestamp.blank?

        Time.at(Integer(timestamp))
      rescue ArgumentError, TypeError
        Time.current
      end

      # SendGrid uses a single "bounce" event; type "blocked" is a soft bounce.
      def adjust_bounce_type(event_type, event)
        return event_type unless event_type == "bounced"
        return "soft_bounced" if event["type"].to_s.casecmp("blocked").zero?

        event_type
      end
    end
  end
end
