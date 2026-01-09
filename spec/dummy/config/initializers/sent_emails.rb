# frozen_string_literal: true

SentEmails.configure do |config|
  # Configure webhook providers for testing
  config.provider :mailpace do |p|
    p.public_key = "6d25ab3aac5f8be30e3f5b0e2e8b0c1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7"
  end
end
