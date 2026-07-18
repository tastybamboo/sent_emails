# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Webhook signature verification", type: :request do
  let(:private_key_hex) { "369c6b4072fe3f2e73e80d5a77606557d188ddb30948848e8a086901ce9cd274" }
  let(:public_key_hex) { "54858f0fb53de28b5e5fd746bbd1da36f1c03998c5de6091b4a4f81b21862201" }

  let(:payload) do
    {
      event: "email.delivered",
      payload: {
        message_id: "test-message-id",
        timestamp: Time.current.iso8601
      }
    }
  end

  let(:raw_body) { payload.to_json }
  let(:signature) { sign_mailpace_payload(raw_body, private_key_hex) }

  before do
    SentEmails.configure do |config|
      config.provider :mailpace do |p|
        p.public_key = public_key_hex
      end
    end
  end

  it "returns ok for a validly signed mailpace webhook" do
    post "/admin/sent_emails/webhooks/mailpace",
      params: raw_body,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-MailPace-Signature" => signature
      }

    expect(response).to have_http_status(:ok)
  end

  it "returns unauthorized for an invalid signature" do
    post "/admin/sent_emails/webhooks/mailpace",
      params: raw_body,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-MailPace-Signature" => "badbadbadbad"
      }

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns unauthorized when signature header is missing" do
    post "/admin/sent_emails/webhooks/mailpace",
      params: raw_body,
      headers: {"CONTENT_TYPE" => "application/json"}

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns not_found for an unknown provider" do
    post "/admin/sent_emails/webhooks/unknown",
      params: raw_body,
      headers: {"CONTENT_TYPE" => "application/json"}

    expect(response).to have_http_status(:not_found)
  end

  context "with a mailgun webhook" do
    let(:mailgun_signing_key) { "test-mailgun-signing-key-secret" }

    let(:mailgun_payload) do
      build_mailgun_webhook_payload(
        signing_key: mailgun_signing_key,
        message_id: "test-message-id",
        event: "delivered"
      )
    end

    let(:mailgun_raw_body) { mailgun_payload.to_json }

    before do
      SentEmails.configure do |config|
        config.provider :mailgun do |p|
          p.signing_key = mailgun_signing_key
        end
      end
    end

    it "returns ok and creates an event for a validly signed mailgun webhook" do
      SentEmails::Email.create!(
        from_address: "test@example.com",
        to_addresses: ["recipient@example.com"],
        message_id: "test-message-id",
        status: "sent"
      )

      expect {
        post "/admin/sent_emails/webhooks/mailgun",
          params: mailgun_raw_body,
          headers: {"CONTENT_TYPE" => "application/json"}
      }.to change(SentEmails::Event, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it "returns unauthorized for an invalid signature" do
      tampered_payload = mailgun_payload.dup
      tampered_payload["signature"] = mailgun_payload["signature"].merge("signature" => "0" * 64)

      post "/admin/sent_emails/webhooks/mailgun",
        params: tampered_payload.to_json,
        headers: {"CONTENT_TYPE" => "application/json"}

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
