# frozen_string_literal: true

module SentEmails
  # Represents a sent email captured by the gem
  #
  # Records all important aspects of a sent email:
  # - Rails context (mailer class, action name, parameters)
  # - Email content (from, to, subject, body)
  # - Delivery information (provider, method, settings)
  # - Status tracking (queued, delivered, bounced, etc.)
  #
  # @example Find emails by recipient
  #   SentEmails::Email.to("user@example.com")
  #
  # @example Search emails
  #   SentEmails::Email.search("Welcome")
  #
  # @example View email status
  #   email = SentEmails::Email.first
  #   email.status # => "delivered"
  #   email.latest_event # => #<SentEmails::Event>
  class Email < ApplicationRecord
    self.table_name = "sent_emails_emails"

    has_many :attachments, dependent: :destroy
    has_many :events, dependent: :destroy

    enum :status, {
      pending: "pending",
      queued: "queued",
      sent: "sent",
      delivered: "delivered",
      deferred: "deferred",
      bounced: "bounced",
      soft_bounced: "soft_bounced",
      failed: "failed",
      spam: "spam",
      rejected: "rejected",
      unknown: "unknown"
    }, default: :pending

    validates :from_address, presence: true
    validates :to_addresses, presence: true
    validates :message_id, uniqueness: true, allow_nil: true

    scope :recent, -> { order(created_at: :desc) }
    scope :by_status, ->(status) { where(status: status) }
    scope :search, ->(query) {
      if using_postgresql?
        where("subject ILIKE :q OR :q = ANY(to_addresses)", q: "%#{query}%")
      else
        pattern = "%#{query}%"
        where("subject LIKE ?", pattern)
          .or(where("to_addresses LIKE ?", "%#{query}%"))
      end
    }

    # Find by recipient email address
    scope :to, ->(email) {
      if using_postgresql?
        where("? = ANY(to_addresses)", email)
      else
        where("to_addresses LIKE ?", "%#{email}%")
      end
    }

    # Latest status based on events
    def latest_event
      events.order(occurred_at: :desc).first
    end

    # Human-readable mailer name
    def mailer_name
      mailer&.underscore&.humanize || "Unknown"
    end

    # Full template identifier
    def template_identifier
      return nil unless mailer && action
      "#{mailer.underscore}/#{action}"
    end

    # Check if email has HTML content
    def html?
      html_body.present?
    end

    # Check if email has text content
    def text?
      text_body.present?
    end

    # Primary recipient (first to address)
    def primary_recipient
      to_addresses&.first
    end

    # All recipients combined
    def all_recipients
      [to_addresses, cc_addresses, bcc_addresses].flatten.compact.uniq
    end

    # Provider display name
    def provider_name
      provider&.titleize || delivery_method&.titleize || "Unknown"
    end

    private

    # Check if using PostgreSQL database
    # @return [Boolean]
    def self.using_postgresql?
      connection.adapter_name.downcase == "postgresql"
    end
  end
end
