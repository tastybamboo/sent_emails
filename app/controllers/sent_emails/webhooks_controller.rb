# frozen_string_literal: true

module SentEmails
  class WebhooksController < ApplicationController
    # Webhooks come from external services, not browsers
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate!

    before_action :verify_provider
    before_action :build_provider
    before_action :verify_signature

    def create
      events = @provider.process!

      if events.any?
        Rails.logger.info("[SentEmails] Processed #{events.size} event(s) from #{params[:provider]}")
      else
        Rails.logger.info("[SentEmails] No matching emails found for webhook from #{params[:provider]}")
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
        Rails.logger.warn("[SentEmails] Unknown provider: #{params[:provider]}")
        head :not_found
      end
    end

    def build_provider
      @provider = provider_class.new(
        payload: webhook_params,
        headers: request.headers.to_h,
        raw_body: request.raw_post
      )
    end

    def verify_signature
      unless @provider.valid_signature?
        Rails.logger.warn("[SentEmails] Invalid signature for #{params[:provider]} webhook")
        head :unauthorized
      end
    end

    def provider_class
      @provider_class ||= case params[:provider]&.downcase
      when "mailpace"
        Providers::Mailpace
        # Future providers:
        # when "sendgrid"
        #   Providers::Sendgrid
        # when "postmark"
        #   Providers::Postmark
      end
    end

    def webhook_params
      # Allow all params since webhook payloads vary by provider
      params.permit!.to_h.except(:controller, :action, :provider)
    end
  end
end
