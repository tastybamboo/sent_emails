# frozen_string_literal: true

require "spec_helper"

RSpec.describe SentEmails::Capture do
  let(:message) do
    Mail.new do
      from "sender@example.com"
      to "recipient@example.com"
      cc "cc@example.com"
      bcc "bcc@example.com"
      subject "Test Subject"
      body "Test body"
      message_id "<test@example.com>"
    end
  end

  let(:delivery_settings) { {address: "smtp.mailpace.com", port: 587} }

  def capture_email(msg = message, settings = delivery_settings)
    SentEmails::Capture.call(
      message: msg,
      mailer: "TestMailer",
      action: "test_action",
      params: {user_id: 1},
      delivery_method: :smtp,
      delivery_settings: settings
    )
  end

  describe ".call" do
    it "creates an Email record" do
      expect { capture_email }.to change(SentEmails::Email, :count).by(1)
    end

    it "captures mailer context" do
      email = capture_email
      expect(email.mailer).to eq("TestMailer")
      expect(email.action).to eq("test_action")
    end

    it "captures email addresses" do
      email = capture_email
      expect(email.from_address).to eq("sender@example.com")
      expect(email.to_addresses).to eq(["recipient@example.com"])
      expect(email.cc_addresses).to eq(["cc@example.com"])
      expect(email.bcc_addresses).to eq(["bcc@example.com"])
    end

    it "captures subject and body" do
      email = capture_email
      expect(email.subject).to eq("Test Subject")
    end

    it "sets status to sent" do
      email = capture_email
      expect(email.status).to eq("sent")
    end

    it "sets message_id" do
      email = capture_email
      expect(email.message_id).to eq("test@example.com")
    end

    it "sanitizes delivery settings" do
      settings = {address: "smtp.mailpace.com", port: 587, password: "secret"}
      email = capture_email(message, settings)

      expect(email.delivery_settings).to include("address" => "smtp.mailpace.com")
      expect(email.delivery_settings).not_to include("password")
    end

    it "detects provider from delivery method" do
      email = SentEmails::Capture.call(
        message: message,
        mailer: "TestMailer",
        action: "test_action",
        params: {},
        delivery_method: :mailpace,
        delivery_settings: {}
      )

      expect(email.provider).to eq("mailpace")
    end

    it "detects provider from SMTP host" do
      settings = {address: "smtp.mailpace.com"}
      email = SentEmails::Capture.call(
        message: message,
        mailer: "TestMailer",
        action: "test_action",
        params: {},
        delivery_method: :smtp,
        delivery_settings: settings
      )

      expect(email.provider).to eq("mailpace")
    end

    context "with attachments" do
      it "captures attachments" do
        msg = Mail.new do
          from "sender@example.com"
          to "recipient@example.com"
          subject "Test with attachment"
          body "Test body"
          message_id "<test@example.com>"
        end
        msg.add_file(filename: "test.txt", content: "test content")

        email = capture_email(msg)
        expect(email.attachments.count).to eq(1)
        attachment = email.attachments.first
        expect(attachment.filename).to eq("test.txt")
        expect(attachment.byte_size).to be > 0
      end
    end
  end
end
