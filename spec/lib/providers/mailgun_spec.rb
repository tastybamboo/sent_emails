# frozen_string_literal: true

require "spec_helper"

RSpec.describe SentEmails::Providers::Mailgun do
  let(:signing_key) { "test-mailgun-signing-key-secret" }

  let(:payload) do
    build_mailgun_webhook_payload(
      signing_key: signing_key,
      message_id: "test-message-id",
      event: "delivered"
    )
  end

  let(:raw_body) { payload.to_json }
  let(:headers) { {} }

  before do
    SentEmails.configure do |config|
      config.provider :mailgun do |p|
        p.signing_key = signing_key
      end
    end
  end

  def build_provider(payload = self.payload, headers = self.headers, body = raw_body)
    SentEmails::Providers::Mailgun.new(
      payload: payload,
      headers: headers,
      raw_body: body
    )
  end

  describe "#valid_signature?" do
    it "returns true for a correctly computed signature" do
      provider = build_provider
      expect(provider.valid_signature?).to be true
    end

    it "returns false when the signature is tampered with" do
      tampered_payload = payload.dup
      tampered_payload["signature"] = payload["signature"].merge("signature" => "0" * 64)
      provider = build_provider(tampered_payload)
      expect(provider.valid_signature?).to be false
    end

    it "returns false when the signing key is not configured" do
      SentEmails.configure do |config|
        config.provider :mailgun do |p|
          p.signing_key = nil
        end
      end

      provider = build_provider
      expect(provider.valid_signature?).to be false
    end

    it "returns false when payload[\"signature\"] is missing entirely" do
      no_signature_payload = payload.dup
      no_signature_payload.delete("signature")
      provider = build_provider(no_signature_payload)
      expect(provider.valid_signature?).to be false
    end

    it "returns false when the timestamp is missing" do
      missing_timestamp_payload = payload.dup
      missing_timestamp_payload["signature"] = payload["signature"].except("timestamp")
      provider = build_provider(missing_timestamp_payload)
      expect(provider.valid_signature?).to be false
    end

    it "returns false when the token is missing" do
      missing_token_payload = payload.dup
      missing_token_payload["signature"] = payload["signature"].except("token")
      provider = build_provider(missing_token_payload)
      expect(provider.valid_signature?).to be false
    end
  end

  describe "#events" do
    described_class::EVENT_MAP.each do |mailgun_event, normalized_event|
      it "maps #{mailgun_event} to #{normalized_event}" do
        event_payload = build_mailgun_webhook_payload(
          signing_key: signing_key,
          message_id: "test-message-id",
          event: mailgun_event
        )
        provider = build_provider(event_payload)
        events = provider.events
        expect(events.first[:event_type]).to eq(normalized_event)
      end
    end

    context "when the event is failed" do
      it "maps severity permanent to bounced" do
        failed_payload = build_mailgun_webhook_payload(
          signing_key: signing_key,
          message_id: "test-message-id",
          event: "failed",
          severity: "permanent"
        )
        provider = build_provider(failed_payload)
        events = provider.events
        expect(events.first[:event_type]).to eq("bounced")
      end

      it "maps severity temporary to soft_bounced" do
        failed_payload = build_mailgun_webhook_payload(
          signing_key: signing_key,
          message_id: "test-message-id",
          event: "failed",
          severity: "temporary"
        )
        provider = build_provider(failed_payload)
        events = provider.events
        expect(events.first[:event_type]).to eq("soft_bounced")
      end

      it "maps a missing severity to deferred" do
        failed_payload = build_mailgun_webhook_payload(
          signing_key: signing_key,
          message_id: "test-message-id",
          event: "failed"
        )
        provider = build_provider(failed_payload)
        events = provider.events
        expect(events.first[:event_type]).to eq("deferred")
      end

      it "maps an unrecognised severity to deferred" do
        failed_payload = build_mailgun_webhook_payload(
          signing_key: signing_key,
          message_id: "test-message-id",
          event: "failed",
          severity: "some-other-severity"
        )
        provider = build_provider(failed_payload)
        events = provider.events
        expect(events.first[:event_type]).to eq("deferred")
      end
    end

    it "returns an empty array for an unmapped event" do
      stored_payload = build_mailgun_webhook_payload(
        signing_key: signing_key,
        message_id: "test-message-id",
        event: "stored"
      )
      provider = build_provider(stored_payload)
      events = provider.events
      expect(events).to be_empty
    end

    it "extracts message_id from event-data.message.headers['message-id']" do
      provider = build_provider
      events = provider.events
      expect(events.first[:message_id]).to eq("test-message-id")
    end

    it "converts a numeric unix epoch timestamp via occurred_at" do
      timestamp = 5.minutes.ago
      ts_payload = build_mailgun_webhook_payload(
        signing_key: signing_key,
        message_id: "test-message-id",
        event: "delivered",
        timestamp: timestamp.to_f
      )
      provider = build_provider(ts_payload)
      events = provider.events
      expect(events.first[:occurred_at]).to be_within(1.second).of(timestamp)
    end

    it "falls back to the current time when the timestamp is missing" do
      missing_ts_payload = payload.dup
      missing_ts_payload["event-data"] = payload["event-data"].except("timestamp")
      provider = build_provider(missing_ts_payload)
      events = provider.events
      expect(events.first[:occurred_at]).to be_within(2.seconds).of(Time.current)
    end

    it "falls back to the current time when the timestamp is invalid" do
      invalid_ts_payload = payload.dup
      invalid_ts_payload["event-data"] = payload["event-data"].merge("timestamp" => "not-a-timestamp")
      provider = build_provider(invalid_ts_payload)
      events = provider.events
      expect(events.first[:occurred_at]).to be_within(2.seconds).of(Time.current)
    end

    it "returns the full event hash shape expected by Base#process!" do
      provider = build_provider
      events = provider.events
      expect(events.length).to eq(1)

      event = events.first
      expect(event.keys).to contain_exactly(:message_id, :event_type, :occurred_at, :payload)
      expect(event[:message_id]).to eq("test-message-id")
      expect(event[:event_type]).to eq("delivered")
      expect(event[:occurred_at]).to be_a(Time)
      expect(event[:payload]).to eq(provider.payload)
    end
  end

  describe "#process!" do
    it "creates event for matching email" do
      SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )

      provider = build_provider
      expect { provider.process! }.to change(SentEmails::Event, :count).by(1)
    end

    it "updates email status based on event" do
      email = SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )

      provider = build_provider
      provider.process!
      expect(email.reload.status).to eq("delivered")
    end

    it "sets delivered_at for delivery events" do
      email = SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )

      provider = build_provider
      provider.process!
      expect(email.reload.delivered_at).not_to be_nil
    end

    it "skips emails without message_id match" do
      non_existent_payload = build_mailgun_webhook_payload(
        signing_key: signing_key,
        message_id: "non-existent-id",
        event: "delivered"
      )
      provider = build_provider(non_existent_payload)
      events = provider.process!
      expect(events).to be_empty
    end

    it "stores provider name in event" do
      SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )

      provider = build_provider
      events = provider.process!
      expect(events.first.provider).to eq("mailgun")
    end
  end
end
