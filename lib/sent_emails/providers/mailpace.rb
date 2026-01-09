# frozen_string_literal: true

require "ed25519"

module SentEmails
  module Providers
    class Mailpace < Base
      # Map Mailpace event types to our normalized types
      # https://docs.mailpace.com/guide/webhooks
      EVENT_MAP = {
        "email.queued" => "queued",
        "email.delivered" => "delivered",
        "email.deferred" => "deferred",
        "email.bounced" => "bounced",
        "email.spam" => "spam"
      }.freeze

      def valid_signature?
        signature = headers["X-MailPace-Signature"] || headers["HTTP_X_MAILPACE_SIGNATURE"]
        return false if signature.blank?

        public_key_hex = provider_config[:public_key]
        return false if public_key_hex.blank?

        verify_ed25519_signature(signature, public_key_hex)
      end

      def events
        event_type = normalize_event_type(payload["event"])
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
        SentEmails.provider_config(:mailpace)
      end

      def verify_ed25519_signature(signature_hex, public_key_hex)
        verify_key = Ed25519::VerifyKey.new([public_key_hex].pack("H*"))
        signature_bytes = [signature_hex].pack("H*")

        # Mailpace signs the raw request body
        verify_key.verify(signature_bytes, raw_body)
        true
      rescue Ed25519::VerifyError, ArgumentError => e
        Rails.logger.warn("[SentEmails::Mailpace] Signature verification failed: #{e.message}")
        false
      end

      def extract_message_id
        # Mailpace includes message ID in the payload
        payload.dig("payload", "message_id") ||
          payload.dig("data", "message_id") ||
          payload["message_id"]
      end

      def extract_timestamp
        timestamp = payload.dig("payload", "timestamp") ||
          payload.dig("data", "timestamp") ||
          payload["timestamp"]

        timestamp ? Time.parse(timestamp) : Time.current
      rescue ArgumentError
        Time.current
      end
    end
  end
end
