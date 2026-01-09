# frozen_string_literal: true

module SpecHelpers
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
    signature_hex = signing_key.sign(payload_json).unpack("H*")[0]
    signature_hex
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
end
