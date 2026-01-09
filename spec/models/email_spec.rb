# frozen_string_literal: true

require "spec_helper"

RSpec.describe SentEmails::Email, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:attachments) }
    it { is_expected.to have_many(:events) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:from_address) }
    it { is_expected.to validate_presence_of(:to_addresses) }
  end

  describe "scopes" do
    describe ".active" do
      it "returns non-archived emails" do
        active = create_email
        archived = create_email(archived_at: 1.hour.ago)

        results = SentEmails::Email.active
        expect(results).to include(active)
        expect(results).not_to include(archived)
      end
    end

    describe ".archived" do
      it "returns archived emails" do
        active = create_email
        archived = create_email(archived_at: 1.hour.ago)

        results = SentEmails::Email.archived
        expect(results).to include(archived)
        expect(results).not_to include(active)
      end
    end

    describe ".recent" do
      it "returns emails ordered by creation date descending" do
        old = create_email(created_at: 2.days.ago)
        new = create_email(created_at: 1.hour.ago)

        result = SentEmails::Email.recent
        expect(result.first.id).to eq(new.id)
        expect(result.last.id).to eq(old.id)
      end

      it "excludes archived emails" do
        active = create_email
        archived = create_email(archived_at: 1.hour.ago)

        results = SentEmails::Email.recent
        expect(results).to include(active)
        expect(results).not_to include(archived)
      end
    end

    describe ".by_status" do
      it "filters emails by status" do
        delivered = create_email(status: :delivered)
        pending = create_email(status: :pending)

        results = SentEmails::Email.by_status(:delivered)
        expect(results).to include(delivered)
        expect(results).not_to include(pending)
      end
    end

    describe ".search" do
      it "searches by subject" do
        email = create_email(subject: "Welcome to our service")
        results = SentEmails::Email.search("Welcome")
        expect(results).to include(email)
      end

      it "searches by recipient" do
        email = create_email(to_addresses: ["user@example.com"])
        results = SentEmails::Email.search("user@example.com")
        expect(results).to include(email)
      end
    end

    describe ".to" do
      it "filters emails by recipient" do
        email = create_email(to_addresses: ["user@example.com"])
        results = SentEmails::Email.to("user@example.com")
        expect(results).to include(email)
      end
    end
  end

  describe "#latest_event" do
    it "returns the most recent event" do
      email = create_email
      old_event = SentEmails::Event.create!(email: email, event_type: "queued", provider: "test", occurred_at: 1.hour.ago)
      new_event = SentEmails::Event.create!(email: email, event_type: "delivered", provider: "test", occurred_at: 30.minutes.ago)

      expect(email.latest_event).to eq(new_event)
    end

    it "returns nil when no events exist" do
      email = create_email
      expect(email.latest_event).to be_nil
    end
  end

  describe "#mailer_name" do
    it "humanizes the mailer class name" do
      email = create_email(mailer: "UserMailer")
      expect(email.mailer_name).to eq("User mailer")
    end

    it "returns Unknown for nil mailer" do
      email = create_email(mailer: nil)
      expect(email.mailer_name).to eq("Unknown")
    end
  end

  describe "#template_identifier" do
    it "returns mailer/action format" do
      email = create_email(mailer: "UserMailer", action: "welcome_email")
      expect(email.template_identifier).to eq("user_mailer/welcome_email")
    end

    it "returns nil if mailer or action is missing" do
      email = create_email(mailer: "UserMailer", action: nil)
      expect(email.template_identifier).to be_nil
    end
  end

  describe "#primary_recipient" do
    it "returns the first recipient" do
      email = create_email(to_addresses: ["first@example.com", "second@example.com"])
      expect(email.primary_recipient).to eq("first@example.com")
    end
  end

  describe "#all_recipients" do
    it "combines to, cc, and bcc addresses" do
      email = create_email(
        to_addresses: ["to@example.com"],
        cc_addresses: ["cc@example.com"],
        bcc_addresses: ["bcc@example.com"]
      )

      recipients = email.all_recipients
      expect(recipients).to include("to@example.com")
      expect(recipients).to include("cc@example.com")
      expect(recipients).to include("bcc@example.com")
    end

    it "returns unique recipients" do
      email = create_email(
        to_addresses: ["user@example.com"],
        cc_addresses: ["user@example.com"]
      )

      recipients = email.all_recipients
      expect(recipients.uniq.length).to eq(recipients.length)
    end
  end

  describe "#archived?" do
    it "returns true when archived_at is set" do
      email = create_email(archived_at: 1.hour.ago)
      expect(email.archived?).to be true
    end

    it "returns false when archived_at is nil" do
      email = create_email
      expect(email.archived?).to be false
    end
  end

  describe "#archive!" do
    it "sets archived_at to current time" do
      email = create_email
      expect { email.archive! }.to change { email.archived? }.from(false).to(true)
      expect(email.archived_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "#unarchive!" do
    it "clears archived_at" do
      email = create_email(archived_at: 1.hour.ago)
      expect { email.unarchive! }.to change { email.archived? }.from(true).to(false)
      expect(email.archived_at).to be_nil
    end
  end

  private

  def create_email(attrs = {})
    defaults = {
      from_address: "noreply@example.com",
      to_addresses: ["user@example.com"],
      status: "sent"
    }
    SentEmails::Email.create!(defaults.merge(attrs))
  end
end
