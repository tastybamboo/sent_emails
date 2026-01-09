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

    # Archive scopes - use active by default in queries
    scope :active, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }

    scope :recent, -> { active.order(created_at: :desc) }
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

    # Eager load events for performance
    scope :with_events, -> { includes(:events) }

    # Latest status based on events
    def latest_event
      # Use already-loaded events if available (from eager loading)
      return events.max_by(&:occurred_at) if events.loaded?
      # Otherwise query database
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

    # Check if email is multipart (has both HTML and text)
    def multipart?
      html? && text?
    end

    # Email format description
    def format_description
      if multipart?
        "HTML and Text (Multipart)"
      elsif html?
        "HTML Only"
      elsif text?
        "Text Only"
      else
        "Unknown"
      end
    end

    # HTML body with CID images replaced with data URLs
    def html_body_with_embedded_images
      return html_body unless html_body.present?

      result = html_body.dup
      attachments.inline_attachments.each do |attachment|
        next unless attachment.content_id.present? && attachment.data_url.present?

        # Replace cid:content_id references with data URLs
        result.gsub!(/cid:#{Regexp.escape(attachment.content_id)}/i, attachment.data_url)
      end
      result
    end

    # All headers including standard ones stored in dedicated columns
    def all_headers
      standard = {
        "From" => from_address,
        "To" => to_addresses&.join(", "),
        "Subject" => subject,
        "Date" => sent_at&.rfc2822 || created_at.rfc2822,
        "Message-ID" => message_id
      }

      standard["Cc"] = cc_addresses.join(", ") if cc_addresses&.any?
      standard["Bcc"] = bcc_addresses.join(", ") if bcc_addresses&.any?

      # Merge with custom headers (custom headers come after standard)
      standard.merge(headers || {}).compact
    end

    # Generate a raw message representation
    def raw_message
      lines = []

      # Headers
      all_headers.each do |name, value|
        lines << "#{name}: #{value}"
      end

      lines << "Content-Type: #{format_content_type}"
      lines << "MIME-Version: 1.0"
      lines << ""

      # Body
      if multipart?
        boundary = "----=_Part_#{id}_#{created_at.to_i}"
        lines << "Content-Type: multipart/alternative; boundary=\"#{boundary}\""
        lines << ""

        if text_body.present?
          lines << "--#{boundary}"
          lines << "Content-Type: text/plain; charset=UTF-8"
          lines << ""
          lines << text_body
          lines << ""
        end

        if html_body.present?
          lines << "--#{boundary}"
          lines << "Content-Type: text/html; charset=UTF-8"
          lines << ""
          lines << html_body
          lines << ""
        end

        lines << "--#{boundary}--"
      elsif html_body.present?
        lines << html_body
      elsif text_body.present?
        lines << text_body
      end

      lines.join("\n")
    end

    private

    def format_content_type
      if multipart?
        "multipart/alternative"
      elsif html?
        "text/html; charset=UTF-8"
      else
        "text/plain; charset=UTF-8"
      end
    end

    public

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

    # Check if email is archived
    def archived?
      archived_at.present?
    end

    # Archive the email (soft-delete)
    def archive!
      update!(archived_at: Time.current)
    end

    # Restore an archived email
    def unarchive!
      update!(archived_at: nil)
    end

    private

    # Check if using PostgreSQL database
    # @return [Boolean]
    def self.using_postgresql?
      connection.adapter_name.downcase == "postgresql"
    end
  end
end
