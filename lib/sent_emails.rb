# frozen_string_literal: true

require_relative "sent_emails/version"
require_relative "sent_emails/configuration"
require_relative "sent_emails/engine"
require_relative "sent_emails/mailer_helper"
require_relative "sent_emails/capture"
require_relative "sent_emails/providers/base"
require_relative "sent_emails/providers/mailpace"

module SentEmails
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def enabled?
      configuration.enabled
    end

    # Get provider-specific configuration
    def provider_config(provider_name)
      configuration.providers[provider_name.to_sym] || {}
    end
  end
end
