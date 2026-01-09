# frozen_string_literal: true

module SentEmails
  module ActionMailerHook
    def deliver_now
      capture_email_before_delivery
      super
    end

    def deliver_later(*)
      capture_email_before_delivery
      super
    end

    private

    def capture_email_before_delivery
      return unless SentEmails.enabled?
      return unless @mail_message

      SentEmails::Capture.call(
        message: @mail_message,
        mailer: @mailer_class.name,
        action: @action,
        params: @args.first || {},
        delivery_method: extract_delivery_method,
        delivery_settings: extract_delivery_settings
      )
    rescue => e
      Rails.logger.error("[SentEmails] Failed to capture email: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
    end

    def extract_delivery_method
      @mail_message.delivery_method.class.name.demodulize.underscore.to_sym
    rescue
      :unknown
    end

    def extract_delivery_settings
      settings = @mail_message.delivery_method.settings
      settings.is_a?(Hash) ? settings : {}
    rescue
      {}
    end
  end
end
