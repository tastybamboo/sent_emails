# frozen_string_literal: true

module SentEmails
  module MailerHelper
    extend ActiveSupport::Concern

    included do
      after_deliver :capture_sent_email
    end

    private

    def capture_sent_email
      return unless SentEmails.enabled?

      SentEmails::Capture.call(
        message: message,
        mailer: self.class.name,
        action: action_name,
        params: params,
        delivery_method: extract_delivery_method,
        delivery_settings: extract_delivery_settings
      )
    rescue => e
      # Don't let email capture failures prevent email delivery
      Rails.logger.error("[SentEmails] Failed to capture email: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
    end

    def extract_delivery_method
      message.delivery_method.class.name.demodulize.underscore.to_sym
    rescue
      :unknown
    end

    def extract_delivery_settings
      settings = message.delivery_method.settings
      settings.is_a?(Hash) ? settings : {}
    rescue
      {}
    end
  end
end
