# frozen_string_literal: true

module SentEmails
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
      where("subject ILIKE :q OR :q = ANY(to_addresses)", q: "%#{query}%")
    }

    # Find by recipient email address
    scope :to, ->(email) { where("? = ANY(to_addresses)", email) }

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
  end
end
