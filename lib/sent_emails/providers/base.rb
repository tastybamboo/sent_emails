# frozen_string_literal: true

module SentEmails
  module Providers
    class Base
      attr_reader :payload, :headers, :raw_body

      def initialize(payload:, headers:, raw_body: nil)
        @payload = payload.with_indifferent_access
        @headers = headers.with_indifferent_access
        @raw_body = raw_body
      end

      # Verify the webhook signature is valid
      # @return [Boolean]
      def valid_signature?
        raise NotImplementedError, "#{self.class} must implement #valid_signature?"
      end

      # Extract events from the webhook payload
      # @return [Array<Hash>] Array of event hashes with keys:
      #   - message_id: String
      #   - event_type: String (queued, sent, delivered, bounced, etc.)
      #   - occurred_at: Time
      #   - payload: Hash (raw event data)
      def events
        raise NotImplementedError, "#{self.class} must implement #events"
      end

      # Provider name for logging and storage
      # @return [String]
      def provider_name
        self.class.name.demodulize.underscore
      end

      # Map provider-specific event type to our normalized types
      # @return [String, nil]
      def normalize_event_type(provider_event)
        self.class::EVENT_MAP[provider_event]
      end

      # Process the webhook and create events
      # @return [Array<SentEmails::Event>] Created events
      def process!
        created_events = []

        events.each do |event_data|
          email = find_email(event_data[:message_id])
          next unless email

          event_payload = event_data[:payload]
          event_payload = redact_event_payload(event_payload, email) if email.redacted?

          event = email.events.create!(
            event_type: event_data[:event_type],
            provider: provider_name,
            payload: event_payload,
            occurred_at: event_data[:occurred_at]
          )

          update_email_status(email, event_data[:event_type])
          notify_subscribers(email, event)
          created_events << event
        end

        created_events
      end

      private

      def notify_subscribers(email, event)
        ActiveSupport::Notifications.instrument("event.sent_emails", {
          email: email,
          event: event,
          event_type: event.event_type,
          to: email.primary_recipient,
          occurred_at: event.occurred_at
        })
      rescue => e
        Rails.logger.error(
          "[SentEmails] Error notifying subscribers for message #{event&.id || "unknown"}: #{e.class}: #{e.message}"
        )
      end

      REDACTED_KEYS = %w[
        to from to_address from_address email recipient sender
        subject htmlbody textbody
      ].freeze

      # Scrub PII from webhook event payloads for redacted emails.
      # Recursively walks hashes/arrays with case-insensitive key matching
      # to handle provider-specific casing (e.g. Postmark capitalises keys).
      def redact_event_payload(payload, _email)
        redact_value(payload)
      end

      def redact_value(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, v), result|
            if REDACTED_KEYS.include?(key.to_s.downcase)
              result[key] = "[REDACTED]"
            else
              result[key] = redact_value(v)
            end
          end
        when Array
          value.map { |v| redact_value(v) }
        else
          value
        end
      end

      def find_email(message_id)
        return nil if message_id.blank?

        Email.find_by(message_id: message_id)
      end

      def update_email_status(email, event_type)
        new_status = status_for_event(event_type)
        return unless new_status

        email.update!(
          status: new_status,
          delivered_at: (Time.current if event_type == "delivered")
        )
      end

      def status_for_event(event_type)
        case event_type
        when "queued" then :queued
        when "sent" then :sent
        when "delivered" then :delivered
        when "deferred" then :deferred
        when "bounced" then :bounced
        when "soft_bounced" then :soft_bounced
        when "failed" then :failed
        when "spam" then :spam
        when "rejected" then :rejected
        end
      end
    end
  end
end
