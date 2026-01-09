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
      :primary_key_type

    def initialize
      @enabled = true
      @attachment_storage = :active_storage
      @max_attachment_size = 10 * 1024 * 1024 # 10 MB
      @retention_period = 90.days
      @authentication_method = nil
      @base_controller = "ApplicationController"
      @providers = {}
      @primary_key_type = :bigint # :bigint or :uuid
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
      :enabled

    def initialize
      @enabled = true
    end

    def to_h
      {
        public_key: @public_key,
        verification_key: @verification_key,
        webhook_token: @webhook_token,
        enabled: @enabled
      }.compact
    end
  end
end
