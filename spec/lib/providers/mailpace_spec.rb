# frozen_string_literal: true

require "spec_helper"

RSpec.describe SentEmails::Providers::Mailpace do
  let(:private_key_hex) { "369c6b4072fe3f2e73e80d5a77606557d188ddb30948848e8a086901ce9cd274" }
  let(:public_key_hex) { "54858f0fb53de28b5e5fd746bbd1da36f1c03998c5de6091b4a4f81b21862201" }

  let(:payload) do
    {
      event: "email.queued",
      payload: {
        message_id: "test-message-id",
        timestamp: Time.current.iso8601
      }
    }
  end

  let(:raw_body) { payload.to_json }
  let(:signature) { sign_mailpace_payload(raw_body, private_key_hex) }
  let(:headers) { {"X-MailPace-Signature" => signature} }

  before do
    SentEmails.configure do |config|
      config.provider :mailpace do |p|
        p.public_key = public_key_hex
      end
    end
  end

  def build_provider(payload = self.payload, headers = self.headers, body = raw_body)
    SentEmails::Providers::Mailpace.new(
      payload: payload,
      headers: headers,
      raw_body: body
    )
  end

  describe "#valid_signature?" do
    it "returns true for valid signature" do
      provider = build_provider
      expect(provider.valid_signature?).to be true
    end

    it "returns false for invalid signature" do
      bad_headers = {"X-MailPace-Signature" => "invalid"}
      provider = build_provider(payload, bad_headers, raw_body)
      expect(provider.valid_signature?).to be false
    end

    it "returns false if signature header missing" do
      provider = build_provider(payload, {}, raw_body)
      expect(provider.valid_signature?).to be false
    end
  end

  describe "#events" do
    it "extracts event from payload" do
      provider = build_provider
      events = provider.events
      expect(events.length).to eq(1)
      expect(events.first[:event_type]).to eq("queued")
      expect(events.first[:message_id]).to eq("test-message-id")
    end

    it "handles delivered event" do
      delivered_payload = payload.dup
      delivered_payload[:event] = "email.delivered"
      provider = build_provider(delivered_payload)
      events = provider.events
      expect(events.first[:event_type]).to eq("delivered")
    end

    it "returns empty array for unknown event" do
      unknown_payload = payload.dup
      unknown_payload[:event] = "email.unknown"
      provider = build_provider(unknown_payload)
      events = provider.events
      expect(events).to be_empty
    end

    it "extracts timestamp from payload" do
      timestamp = 5.minutes.ago
      ts_payload = payload.dup
      ts_payload[:payload][:timestamp] = timestamp.iso8601
      provider = build_provider(ts_payload)
      events = provider.events
      expect(events.first[:occurred_at]).to be_within(1.second).of(timestamp)
    end
  end

  describe "#process!" do
    it "creates event for matching email" do
      email = SentEmails::Email.create!(
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
      expect(email.reload.status).to eq("queued")
    end

    it "skips emails without message_id match" do
      non_existent_payload = payload.dup
      non_existent_payload[:payload][:message_id] = "non-existent-id"
      provider = build_provider(non_existent_payload)
      events = provider.process!
      expect(events).to be_empty
    end

    it "handles delivered event and sets delivered_at" do
      email = SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )

      delivered_payload = payload.dup
      delivered_payload[:event] = "email.delivered"
      provider = build_provider(delivered_payload)
      provider.process!
      expect(email.reload.status).to eq("delivered")
      expect(email.delivered_at).not_to be_nil
    end

    it "handles bounced event" do
      email = SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )

      bounced_payload = payload.dup
      bounced_payload[:event] = "email.bounced"
      provider = build_provider(bounced_payload)
      provider.process!
      expect(email.reload.status).to eq("bounced")
    end
  end
end
