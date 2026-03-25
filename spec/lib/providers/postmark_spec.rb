# frozen_string_literal: true

require "spec_helper"

RSpec.describe SentEmails::Providers::Postmark do
  let(:webhook_token) { "test-webhook-token-secret" }

  let(:payload) do
    {
      "RecordType" => "Delivery",
      "MessageID" => "test-message-id",
      "DeliveredAt" => Time.current.iso8601
    }
  end

  let(:raw_body) { payload.to_json }
  let(:signature) { sign_postmark_payload(raw_body, webhook_token) }
  let(:headers) { {"X-Postmark-Signature" => signature} }

  before do
    SentEmails.configure do |config|
      config.provider :postmark do |p|
        p.webhook_token = webhook_token
      end
    end
  end

  def build_provider(payload = self.payload, headers = self.headers, body = raw_body)
    SentEmails::Providers::Postmark.new(
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
      bad_headers = {"X-Postmark-Signature" => "invalid"}
      provider = build_provider(payload, bad_headers, raw_body)
      expect(provider.valid_signature?).to be false
    end

    it "returns false if signature header missing" do
      provider = build_provider(payload, {}, raw_body)
      expect(provider.valid_signature?).to be false
    end

    it "handles HTTP_ prefixed headers (Rack format)" do
      rack_headers = {"HTTP_X_POSTMARK_SIGNATURE" => signature}
      provider = build_provider(payload, rack_headers, raw_body)
      expect(provider.valid_signature?).to be true
    end
  end

  describe "#events" do
    it "extracts event from payload" do
      provider = build_provider
      events = provider.events
      expect(events.length).to eq(1)
      expect(events.first[:event_type]).to eq("delivered")
      expect(events.first[:message_id]).to eq("test-message-id")
    end

    it "handles Bounce event" do
      bounce_payload = build_postmark_webhook_payload(
        message_id: "test-message-id",
        record_type: "Bounce",
        bounce_type: "HardBounce",
        type_code: 1
      )
      provider = build_provider(bounce_payload)
      events = provider.events
      expect(events.first[:event_type]).to eq("bounced")
    end

    it "handles soft bounce based on TypeCode" do
      soft_bounce_payload = build_postmark_webhook_payload(
        message_id: "test-message-id",
        record_type: "Bounce",
        bounce_type: "Transient",
        type_code: 450
      )
      provider = build_provider(soft_bounce_payload)
      events = provider.events
      expect(events.first[:event_type]).to eq("soft_bounced")
    end

    it "handles SpamComplaint event" do
      spam_payload = payload.dup
      spam_payload["RecordType"] = "SpamComplaint"
      provider = build_provider(spam_payload)
      events = provider.events
      expect(events.first[:event_type]).to eq("spam")
    end

    it "handles Open event" do
      open_payload = payload.dup
      open_payload["RecordType"] = "Open"
      provider = build_provider(open_payload)
      events = provider.events
      expect(events.first[:event_type]).to eq("opened")
    end

    it "returns empty array for unknown event" do
      unknown_payload = payload.dup
      unknown_payload["RecordType"] = "UnknownEvent"
      provider = build_provider(unknown_payload)
      events = provider.events
      expect(events).to be_empty
    end

    it "extracts timestamp from DeliveredAt" do
      timestamp = 5.minutes.ago
      ts_payload = payload.dup
      ts_payload["DeliveredAt"] = timestamp.iso8601
      provider = build_provider(ts_payload)
      events = provider.events
      expect(events.first[:occurred_at]).to be_within(1.second).of(timestamp)
    end

    it "extracts timestamp from BouncedAt for bounces" do
      timestamp = 5.minutes.ago
      bounce_payload = build_postmark_webhook_payload(
        message_id: "test-message-id",
        record_type: "Bounce"
      )
      bounce_payload["BouncedAt"] = timestamp.iso8601
      provider = build_provider(bounce_payload)
      events = provider.events
      expect(events.first[:occurred_at]).to be_within(1.second).of(timestamp)
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
      non_existent_payload = payload.dup
      non_existent_payload["MessageID"] = "non-existent-id"
      provider = build_provider(non_existent_payload)
      events = provider.process!
      expect(events).to be_empty
    end

    it "handles bounced event" do
      email = SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )

      bounce_payload = build_postmark_webhook_payload(
        message_id: "test-message-id",
        record_type: "Bounce",
        bounce_type: "HardBounce",
        type_code: 1
      )
      provider = build_provider(bounce_payload)
      provider.process!
      expect(email.reload.status).to eq("bounced")
    end

    it "handles soft bounce event" do
      email = SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )

      soft_bounce_payload = build_postmark_webhook_payload(
        message_id: "test-message-id",
        record_type: "Bounce",
        bounce_type: "Transient",
        type_code: 450
      )
      provider = build_provider(soft_bounce_payload)
      provider.process!
      expect(email.reload.status).to eq("soft_bounced")
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
      expect(events.first.provider).to eq("postmark")
    end
  end

  describe "soft bounce detection" do
    let(:email) do
      SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )
    end

    SentEmails::Providers::Postmark::SOFT_BOUNCE_TYPES.each do |bounce_type|
      it "treats #{bounce_type} as soft bounce" do
        soft_bounce_payload = build_postmark_webhook_payload(
          message_id: "test-message-id",
          record_type: "Bounce",
          bounce_type: bounce_type,
          type_code: 100
        )
        provider = build_provider(soft_bounce_payload)
        events = provider.events
        expect(events.first[:event_type]).to eq("soft_bounced")
      end
    end

    it "treats TypeCode 400-499 as soft bounce regardless of Type" do
      soft_bounce_payload = build_postmark_webhook_payload(
        message_id: "test-message-id",
        record_type: "Bounce",
        bounce_type: "SomeUnknownType",
        type_code: 421
      )
      provider = build_provider(soft_bounce_payload)
      events = provider.events
      expect(events.first[:event_type]).to eq("soft_bounced")
    end

    it "treats TypeCode < 400 with unknown Type as hard bounce" do
      hard_bounce_payload = build_postmark_webhook_payload(
        message_id: "test-message-id",
        record_type: "Bounce",
        bounce_type: "HardBounce",
        type_code: 1
      )
      provider = build_provider(hard_bounce_payload)
      events = provider.events
      expect(events.first[:event_type]).to eq("bounced")
    end
  end
end
