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
end

RSpec.configure do |config|
  config.include SpecHelpers
end
