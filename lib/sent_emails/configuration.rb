# frozen_string_literal: true

module SentEmails
  class Configuration
    attr_accessor :enabled,
      :attachment_storage,
      :max_attachment_size,
      :retention_period,
      :authentication_method,
      :base_controller,
      :providers,
      :primary_key_type,
      :mount_webhooks_in_engine,
      :content_filters,
      :on_signature_failure

    def initialize
      @enabled = true
      @attachment_storage = :database  # Store inline in database for simplicity
      @max_attachment_size = 10 * 1024 * 1024 # 10 MB
      @retention_period = 90.days
      @authentication_method = nil
      @base_controller = "ApplicationController"
      @providers = {}
      @primary_key_type = :bigint # :bigint or :uuid
      @mount_webhooks_in_engine = true # Set to false to mount webhooks separately
      @content_filters = []
      @on_signature_failure = nil
    end

    # Register a content filter that runs before email content is persisted.
    # Filters receive the email attributes hash and can modify it in place
    # (e.g., redact body, subject, or to_addresses for privacy).
    #
    # Example:
    #   config.content_filter do |attrs|
    #     if attrs[:to_addresses]&.any? { |a| a.include?("sensitive") }
    #       attrs[:text_body] = "[Content redacted]"
    #       attrs[:html_body] = "[Content redacted]"
    #       attrs[:subject] = "[Redacted]"
    #     end
    #   end
    def content_filter(&block)
      raise ArgumentError, "content_filter requires a block" unless block_given?

      @content_filters << block
    end

    # Configure a specific provider
    #
    # Example:
    #   config.provider :mailpace do |p|
    #     p.public_key = Rails.application.credentials.dig(:mailpace, :webhook_public_key)
    #   end
    #
    #   config.provider :sendgrid do |p|
    #     p.verification_key = ENV["SENDGRID_WEBHOOK_VERIFICATION_KEY"]
    #   end
    def provider(name, &block)
      provider_config = ProviderConfig.new
      yield(provider_config) if block_given?
      @providers[name.to_sym] = provider_config.to_h
    end
  end

  class ProviderConfig
    attr_accessor :public_key,        # Mailpace Ed25519 public key
      :verification_key,              # SendGrid verification key
      :webhook_token,                 # Postmark webhook token
      :signing_key,                   # Mailgun HTTP webhook signing key
      :enabled

    def initialize
      @enabled = true
    end

    def to_h
      {
        public_key: @public_key,
        verification_key: @verification_key,
        webhook_token: @webhook_token,
        signing_key: @signing_key,
        enabled: @enabled
      }.compact
    end
  end
end
