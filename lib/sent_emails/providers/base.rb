# frozen_string_literal: true

module SentEmails
  module Providers
    class Base
      attr_reader :payload, :headers, :raw_body

      def initialize(payload:, headers:, raw_body: nil)
        @payload = payload
        @headers = headers
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

          event = email.events.create!(
            event_type: event_data[:event_type],
            provider: provider_name,
            payload: event_data[:payload],
            occurred_at: event_data[:occurred_at]
          )

          update_email_status(email, event_data[:event_type])
          created_events << event
        end

        created_events
      end

      private

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
