# frozen_string_literal: true

require "spec_helper"

RSpec.describe SentEmails::TestHelpers do
  describe "email capture testing" do
    before { clear_sent_emails }

    describe "have_sent_email matcher" do
      it "passes when email is sent to recipient" do
        expect {
          SentEmails::Capture.call(
            message: build_test_message(to: "user@example.com"),
            mailer: "TestMailer",
            action: "test",
            params: {},
            delivery_method: :test,
            delivery_settings: {}
          )
        }.to have_sent_email(to: "user@example.com")
      end

      it "fails when no email is sent" do
        expect {
          expect {
            # Nothing sent
          }.to have_sent_email(to: "user@example.com")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it "matches by subject" do
        expect {
          SentEmails::Capture.call(
            message: build_test_message(to: "user@example.com", subject: "Welcome!"),
            mailer: "TestMailer",
            action: "test",
            params: {},
            delivery_method: :test,
            delivery_settings: {}
          )
        }.to have_sent_email(to: "user@example.com", subject: "Welcome!")
      end

      it "matches subject with regex" do
        expect {
          SentEmails::Capture.call(
            message: build_test_message(to: "user@example.com", subject: "Welcome to our service"),
            mailer: "TestMailer",
            action: "test",
            params: {},
            delivery_method: :test,
            delivery_settings: {}
          )
        }.to have_sent_email(to: "user@example.com", subject: /Welcome/)
      end
    end

    describe "#find_sent_email" do
      it "finds email by recipient" do
        SentEmails::Capture.call(
          message: build_test_message(to: "user@example.com"),
          mailer: "TestMailer",
          action: "test",
          params: {},
          delivery_method: :test,
          delivery_settings: {}
        )

        email = find_sent_email(to: "user@example.com")
        expect(email.from_address).to eq("noreply@example.com")
      end

      it "finds email by subject" do
        SentEmails::Capture.call(
          message: build_test_message(to: "user@example.com", subject: "Test Email"),
          mailer: "TestMailer",
          action: "test",
          params: {},
          delivery_method: :test,
          delivery_settings: {}
        )

        email = find_sent_email(to: "user@example.com", subject: "Test Email")
        expect(email.subject).to eq("Test Email")
      end

      it "raises if email not found" do
        expect {
          find_sent_email(to: "nonexistent@example.com")
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "#last_sent_email" do
      it "returns the most recent email to recipient" do
        SentEmails::Capture.call(
          message: build_test_message(to: "user@example.com", subject: "First"),
          mailer: "TestMailer",
          action: "test",
          params: {},
          delivery_method: :test,
          delivery_settings: {}
        )

        SentEmails::Capture.call(
          message: build_test_message(to: "user@example.com", subject: "Second"),
          mailer: "TestMailer",
          action: "test",
          params: {},
          delivery_method: :test,
          delivery_settings: {}
        )

        email = last_sent_email(to: "user@example.com")
        expect(email.subject).to eq("Second")
      end
    end

    describe "#count_sent_emails" do
      it "counts emails to recipient" do
        2.times do |i|
          SentEmails::Capture.call(
            message: build_test_message(to: "user@example.com", subject: "Email #{i}"),
            mailer: "TestMailer",
            action: "test",
            params: {},
            delivery_method: :test,
            delivery_settings: {}
          )
        end

        expect(count_sent_emails(to: "user@example.com")).to eq(2)
      end

      it "counts all emails" do
        SentEmails::Capture.call(
          message: build_test_message(to: "user1@example.com"),
          mailer: "TestMailer",
          action: "test",
          params: {},
          delivery_method: :test,
          delivery_settings: {}
        )

        SentEmails::Capture.call(
          message: build_test_message(to: "user2@example.com"),
          mailer: "TestMailer",
          action: "test",
          params: {},
          delivery_method: :test,
          delivery_settings: {}
        )

        expect(count_sent_emails).to eq(2)
      end
    end

    describe "#find_sent_emails" do
      it "returns all emails to recipient" do
        2.times { |i|
          SentEmails::Capture.call(
            message: build_test_message(to: "user@example.com", subject: "Email #{i}"),
            mailer: "TestMailer",
            action: "test",
            params: {},
            delivery_method: :test,
            delivery_settings: {}
          )
        }

        emails = find_sent_emails(to: "user@example.com")
        expect(emails.count).to eq(2)
      end
    end

    describe "#clear_sent_emails" do
      it "deletes all captured emails" do
        SentEmails::Capture.call(
          message: build_test_message(to: "user@example.com"),
          mailer: "TestMailer",
          action: "test",
          params: {},
          delivery_method: :test,
          delivery_settings: {}
        )

        expect(SentEmails::Email.count).to eq(1)
        clear_sent_emails
        expect(SentEmails::Email.count).to eq(0)
      end
    end
  end

  private

  def build_test_message(to: "recipient@example.com", subject: "Test")
    Mail.new do
      from "noreply@example.com"
      to to
      subject subject
      body "Test email body"
      message_id "<test-#{SecureRandom.uuid}@example.com>"
    end
  end
end
