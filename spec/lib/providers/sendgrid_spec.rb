# frozen_string_literal: true

require "spec_helper"

RSpec.describe SentEmails::Providers::Sendgrid do
  let(:keypair) { generate_sendgrid_ecdsa_keypair }
  let(:private_key) { keypair[0] }
  let(:verification_key) { keypair[1] }

  let(:payload_array) do
    build_sendgrid_webhook_payload(
      message_id: "test-message-id",
      event: "delivered"
    )
  end

  let(:raw_body) { payload_array.to_json }
  let(:timestamp) { Time.current.to_i.to_s }
  let(:signature) { sign_sendgrid_payload(private_key, raw_body, timestamp: timestamp) }
  let(:headers) do
    {
      "X-Twilio-Email-Event-Webhook-Signature" => signature,
      "X-Twilio-Email-Event-Webhook-Timestamp" => timestamp
    }
  end

  # Rails wraps JSON arrays under `_json` when parsing request parameters.
  let(:payload) { {"_json" => payload_array} }

  before do
    SentEmails.configure do |config|
      config.provider :sendgrid do |p|
        p.verification_key = verification_key
      end
    end
  end

  def build_provider(payload = self.payload, headers = self.headers, body = raw_body)
    SentEmails::Providers::Sendgrid.new(
      payload: payload,
      headers: headers,
      raw_body: body
    )
  end

  describe "#valid_signature?" do
    it "returns true for a correctly computed ECDSA signature" do
      provider = build_provider
      expect(provider.valid_signature?).to be true
    end

    it "returns false when the signature is tampered with" do
      bad_headers = headers.merge(
        "X-Twilio-Email-Event-Webhook-Signature" => Base64.strict_encode64("not-a-valid-signature")
      )
      provider = build_provider(payload, bad_headers)
      expect(provider.valid_signature?).to be false
    end

    it "returns false when the verification key is not configured" do
      SentEmails.configure do |config|
        config.provider :sendgrid do |p|
          p.verification_key = nil
        end
      end

      provider = build_provider
      expect(provider.valid_signature?).to be false
    end

    it "returns false when the signature header is missing" do
      provider = build_provider(payload, headers.except("X-Twilio-Email-Event-Webhook-Signature"))
      expect(provider.valid_signature?).to be false
    end

    it "returns false when the timestamp header is missing" do
      provider = build_provider(payload, headers.except("X-Twilio-Email-Event-Webhook-Timestamp"))
      expect(provider.valid_signature?).to be false
    end

    it "returns false when the raw body is blank" do
      provider = build_provider(payload, headers, "")
      expect(provider.valid_signature?).to be false
    end

    it "accepts Rack-style HTTP_ header names" do
      rack_headers = {
        "HTTP_X_TWILIO_EMAIL_EVENT_WEBHOOK_SIGNATURE" => signature,
        "HTTP_X_TWILIO_EMAIL_EVENT_WEBHOOK_TIMESTAMP" => timestamp
      }
      provider = build_provider(payload, rack_headers)
      expect(provider.valid_signature?).to be true
    end
  end

  describe "#events" do
    described_class::EVENT_MAP.each do |sendgrid_event, normalized_event|
      next if sendgrid_event == "bounce"

      it "maps #{sendgrid_event} to #{normalized_event}" do
        event_payload = build_sendgrid_webhook_payload(
          message_id: "test-message-id",
          event: sendgrid_event
        )
        provider = build_provider({"_json" => event_payload}, headers, event_payload.to_json)
        events = provider.events
        expect(events.first[:event_type]).to eq(normalized_event)
      end
    end

    context "when the event is bounce" do
      it "maps a hard bounce to bounced" do
        bounce_payload = build_sendgrid_webhook_payload(
          message_id: "test-message-id",
          event: "bounce",
          bounce_type: "bounce"
        )
        provider = build_provider({"_json" => bounce_payload}, headers, bounce_payload.to_json)
        expect(provider.events.first[:event_type]).to eq("bounced")
      end

      it "maps type blocked to soft_bounced" do
        bounce_payload = build_sendgrid_webhook_payload(
          message_id: "test-message-id",
          event: "bounce",
          bounce_type: "blocked"
        )
        provider = build_provider({"_json" => bounce_payload}, headers, bounce_payload.to_json)
        expect(provider.events.first[:event_type]).to eq("soft_bounced")
      end
    end

    it "returns an empty array for an unmapped event" do
      unknown_payload = build_sendgrid_webhook_payload(
        message_id: "test-message-id",
        event: "group_resubscribe"
      )
      provider = build_provider({"_json" => unknown_payload}, headers, unknown_payload.to_json)
      expect(provider.events).to be_empty
    end

    it "extracts message_id from smtp-id without angle brackets" do
      provider = build_provider
      expect(provider.events.first[:message_id]).to eq("test-message-id")
    end

    it "falls back to unique_args.message_id when smtp-id is absent" do
      event_payload = build_sendgrid_webhook_payload(
        message_id: "ignored",
        event: "delivered",
        omit_smtp_id: true,
        unique_args: {"message_id" => "from-unique-args"}
      )
      provider = build_provider({"_json" => event_payload}, headers, event_payload.to_json)
      expect(provider.events.first[:message_id]).to eq("from-unique-args")
    end

    it "converts a unix epoch timestamp via occurred_at" do
      ts = 5.minutes.ago.to_i
      ts_payload = build_sendgrid_webhook_payload(
        message_id: "test-message-id",
        event: "delivered",
        timestamp: ts
      )
      provider = build_provider({"_json" => ts_payload}, headers, ts_payload.to_json)
      expect(provider.events.first[:occurred_at]).to be_within(1.second).of(Time.at(ts))
    end

    it "falls back to the current time when the timestamp is missing" do
      missing_ts = payload_array.deep_dup
      missing_ts.first.delete("timestamp")
      provider = build_provider({"_json" => missing_ts}, headers, missing_ts.to_json)
      expect(provider.events.first[:occurred_at]).to be_within(2.seconds).of(Time.current)
    end

    it "processes multiple events from a single batched payload" do
      batch = [
        build_sendgrid_event(message_id: "msg-1", event: "delivered"),
        build_sendgrid_event(message_id: "msg-2", event: "open")
      ]
      provider = build_provider({"_json" => batch}, headers, batch.to_json)
      events = provider.events

      expect(events.length).to eq(2)
      expect(events.map { |e| e[:message_id] }).to eq(["msg-1", "msg-2"])
      expect(events.map { |e| e[:event_type] }).to eq(["delivered", "opened"])
    end

    it "parses events from raw_body when _json is absent" do
      provider = build_provider({}, headers, raw_body)
      expect(provider.events.first[:message_id]).to eq("test-message-id")
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
      expect(event[:payload]).to include("event" => "delivered")
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
      non_existent_payload = build_sendgrid_webhook_payload(
        message_id: "non-existent-id",
        event: "delivered"
      )
      provider = build_provider({"_json" => non_existent_payload}, headers, non_existent_payload.to_json)
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
      expect(events.first.provider).to eq("sendgrid")
    end

    it "creates events for each matching email in a batch" do
      SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["a@example.com"],
        message_id: "msg-1",
        status: "sent"
      )
      SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["b@example.com"],
        message_id: "msg-2",
        status: "sent"
      )

      batch = [
        build_sendgrid_event(message_id: "msg-1", event: "delivered"),
        build_sendgrid_event(message_id: "msg-2", event: "bounce", bounce_type: "bounce")
      ]
      provider = build_provider({"_json" => batch}, headers, batch.to_json)

      expect { provider.process! }.to change(SentEmails::Event, :count).by(2)
    end
  end
end
