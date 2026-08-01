# frozen_string_literal: true

module SpecHelpers
  # Mailpace helpers
  def build_mailpace_webhook_payload(message_id:, event: "email.queued")
    {
      event: event,
      payload: {
        message_id: message_id,
        timestamp: Time.current.iso8601
      }
    }
  end

  def sign_mailpace_payload(payload_json, private_key_hex)
    require "ed25519"
    signing_key = Ed25519::SigningKey.new([private_key_hex].pack("H*"))
    signing_key.sign(payload_json).unpack1("H*")
  end

  # Postmark helpers
  def build_postmark_webhook_payload(message_id:, record_type: "Delivery", **options)
    base = {
      "RecordType" => record_type,
      "MessageID" => message_id,
      "DeliveredAt" => Time.current.iso8601
    }

    # Add bounce-specific fields if this is a bounce
    if record_type == "Bounce"
      base["Type"] = options[:bounce_type] || "HardBounce"
      base["TypeCode"] = options[:type_code] || 1
      base["BouncedAt"] = Time.current.iso8601
      base.delete("DeliveredAt")
    end

    base
  end

  def sign_postmark_payload(payload_json, webhook_token)
    require "openssl"
    OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      webhook_token,
      payload_json
    )
  end

  # Mailgun helpers
  def build_mailgun_event_data(message_id:, event: "delivered", timestamp: Time.current.to_f, **options)
    event_data = {
      "id" => SecureRandom.hex(16),
      "event" => event,
      "timestamp" => timestamp,
      "message" => {
        "headers" => {
          "message-id" => message_id
        }
      }
    }
    event_data["severity"] = options[:severity] if options[:severity]
    event_data
  end

  def sign_mailgun_payload(signing_key, timestamp:, token:)
    require "openssl"
    OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      signing_key,
      "#{timestamp}#{token}"
    )
  end

  def build_mailgun_signature_block(signing_key, timestamp: Time.current.to_i.to_s, token: SecureRandom.hex(20))
    {
      "timestamp" => timestamp,
      "token" => token,
      "signature" => sign_mailgun_payload(signing_key, timestamp: timestamp, token: token)
    }
  end

  def build_mailgun_webhook_payload(signing_key:, message_id:, event: "delivered", timestamp: Time.current.to_f, **options)
    {
      "signature" => build_mailgun_signature_block(signing_key),
      "event-data" => build_mailgun_event_data(message_id: message_id, event: event, timestamp: timestamp, **options)
    }
  end

  # SendGrid helpers
  def build_sendgrid_event(message_id:, event: "delivered", timestamp: Time.current.to_i, **options)
    event_data = {
      "email" => options[:email] || "recipient@example.com",
      "timestamp" => timestamp,
      "event" => event,
      "sg_event_id" => SecureRandom.urlsafe_base64(16),
      "sg_message_id" => "#{SecureRandom.hex(12)}.filter0001.16648.0",
      "smtp-id" => "<#{message_id}>"
    }
    event_data["type"] = options[:bounce_type] if options[:bounce_type]
    event_data["unique_args"] = options[:unique_args] if options[:unique_args]
    event_data["custom_args"] = options[:custom_args] if options[:custom_args]
    event_data.delete("smtp-id") if options[:omit_smtp_id]
    event_data["message_id"] = options[:explicit_message_id] if options.key?(:explicit_message_id)
    event_data
  end

  def build_sendgrid_webhook_payload(message_id:, event: "delivered", timestamp: Time.current.to_i, **options)
    [build_sendgrid_event(message_id: message_id, event: event, timestamp: timestamp, **options)]
  end

  def generate_sendgrid_ecdsa_keypair
    require "openssl"
    require "base64"
    key = OpenSSL::PKey::EC.generate("prime256v1")
    verification_key = Base64.strict_encode64(key.public_to_pem)
    [key, verification_key]
  end

  def sign_sendgrid_payload(private_key, payload_json, timestamp:)
    require "openssl"
    require "base64"
    require "digest"
    digest = Digest::SHA256.digest("#{timestamp}#{payload_json}")
    Base64.strict_encode64(private_key.dsa_sign_asn1(digest))
  end

  def sendgrid_signature_headers(private_key, payload_json, timestamp: Time.current.to_i.to_s)
    {
      "CONTENT_TYPE" => "application/json",
      "X-Twilio-Email-Event-Webhook-Signature" => sign_sendgrid_payload(private_key, payload_json, timestamp: timestamp),
      "X-Twilio-Email-Event-Webhook-Timestamp" => timestamp
    }
  end

  def create_email(attrs = {})
    defaults = {
      from_address: "noreply@example.com",
      to_addresses: ["user@example.com"],
      cc_addresses: [],
      bcc_addresses: [],
      mailer_params: {},
      status: "sent"
    }
    SentEmails::Email.create!(defaults.merge(attrs))
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
end
