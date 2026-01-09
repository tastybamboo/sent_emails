# frozen_string_literal: true

require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)
require "sent_emails"

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.0
    config.root = File.expand_path("../", __dir__)
    config.paths["db/migrate"] = File.expand_path("../../../db/migrate", __dir__)

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
