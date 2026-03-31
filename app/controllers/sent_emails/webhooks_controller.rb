# frozen_string_literal: true

module SentEmails
  class WebhooksController < ApplicationController
    # Webhooks come from external services, not browsers
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate!

    before_action :capture_raw_body
    before_action :verify_provider
    before_action :build_provider
    before_action :verify_signature

    def create
      events = @provider.process!

      if events.any?
        Rails.logger.info("[SentEmails] Processed #{events.size} event(s) from #{provider_name}")
      else
        Rails.logger.info("[SentEmails] No matching emails found for webhook from #{provider_name}")
      end

      head :ok
    rescue => e
      Rails.logger.error("[SentEmails] Webhook processing error: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
      head :unprocessable_entity
    end

    private

    def verify_provider
      unless provider_class
        Rails.logger.warn("[SentEmails] Unknown provider: #{provider_name}")
        head :not_found
      end
    end

    # Capture the raw body before anything else accesses params — params
    # parsing consumes the rack.input stream, which can leave
    # request.raw_post empty when Content-Length is absent (chunked transfer).
    def capture_raw_body
      @raw_body = request.raw_post.presence
      @raw_body ||= begin
        request.body.rewind if request.body.respond_to?(:rewind)
        body = request.body.read
        request.body.rewind if request.body.respond_to?(:rewind)
        body
      end
    end

    def build_provider
      @provider = provider_class.new(
        payload: webhook_params,
        headers: request.headers.to_h,
        raw_body: @raw_body
      )
    end

    def verify_signature
      unless @provider.valid_signature?
        Rails.logger.warn("[SentEmails] Invalid signature for #{provider_name} webhook")
        notify_signature_failure
        head :unauthorized
      end
    end

    def notify_signature_failure
      callback = SentEmails.configuration.on_signature_failure
      return unless callback

      callback.call(provider_name, request)
    rescue => e
      Rails.logger.error("[SentEmails] on_signature_failure callback error: #{e.message}")
    end

    # Use path_parameters to avoid triggering body parsing from params
    def provider_name
      request.path_parameters[:provider]&.downcase
    end

    def provider_class
      @provider_class ||= case provider_name
      when "mailpace"
        Providers::Mailpace
      when "postmark"
        Providers::Postmark
      end
    end

    def webhook_params
      # Allow all params since webhook payloads vary by provider
      params.permit!.to_h.except(:controller, :action, :provider)
    end
  end
end
