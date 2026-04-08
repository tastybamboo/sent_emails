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

        public_key = provider_config[:public_key]
        return false if public_key.blank?

        verify_ed25519_signature(signature, public_key)
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

      def verify_ed25519_signature(signature, public_key_value)
        verify_key = Ed25519::VerifyKey.new(decode_key(public_key_value))
        signature_bytes = decode_signature(signature)

        # Mailpace signs the raw request body
        verify_key.verify(signature_bytes, raw_body)
        true
      rescue Ed25519::VerifyError, ArgumentError => e
        Rails.logger.warn("[SentEmails::Mailpace] Signature verification failed: #{e.message}")
        false
      end

      # Decode a public key from either hex or base64 encoding.
      # Hex keys are 64 characters of [0-9a-fA-F]; everything else is treated as base64.
      def decode_key(value)
        if value.match?(/\A[0-9a-fA-F]{64}\z/)
          [value].pack("H*")
        else
          Base64.strict_decode64(value)
        end
      end

      # Decode an Ed25519 signature from either hex or base64 encoding.
      #
      # Mailpace sends signatures as base64 per their webhook docs:
      # https://docs.mailpace.com/guide/webhooks
      #
      # A valid Ed25519 signature is always 64 bytes:
      # - Hex encoded: 128 characters of [0-9a-fA-F]
      # - Base64 encoded (strict): 88 characters, ending with "=="
      #
      # Hex support is preserved for backwards compatibility with tests and
      # any callers that may pre-encode in hex.
      def decode_signature(value)
        if value.match?(/\A[0-9a-fA-F]{128}\z/)
          [value].pack("H*")
        else
          Base64.strict_decode64(value)
        end
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
