# frozen_string_literal: true

module SentEmails
  class Event < ApplicationRecord
    self.table_name = "sent_emails_events"

    belongs_to :email

    validates :event_type, presence: true
    validates :occurred_at, presence: true

    scope :chronological, -> { order(occurred_at: :asc) }
    scope :reverse_chronological, -> { order(occurred_at: :desc) }
    scope :by_type, ->(type) { where(event_type: type) }

    # Event types that indicate successful delivery
    POSITIVE_EVENTS = %w[queued sent delivered opened clicked].freeze

    # Event types that indicate problems
    NEGATIVE_EVENTS = %w[bounced failed spam deferred].freeze

    # Check if this is a positive event
    def positive?
      POSITIVE_EVENTS.include?(event_type)
    end

    # Check if this is a negative event
    def negative?
      NEGATIVE_EVENTS.include?(event_type)
    end

    # Human-readable event name
    def display_name
      event_type.titleize
    end

    # Icon name for the event (Heroicon names)
    def icon_name
      case event_type
      when "queued"
        "clock"
      when "sent"
        "paper-airplane"
      when "delivered"
        "check-circle"
      when "opened"
        "envelope-open"
      when "clicked"
        "cursor-arrow-rays"
      when "bounced"
        "exclamation-triangle"
      when "failed"
        "x-circle"
      when "spam"
        "shield-exclamation"
      when "deferred"
        "arrow-path"
      else
        "information-circle"
      end
    end

    # CSS class for event badge
    def badge_class
      if positive?
        "bg-green-100 text-green-800"
      elsif negative?
        "bg-red-100 text-red-800"
      else
        "bg-gray-100 text-gray-800"
      end
    end
  end
end
