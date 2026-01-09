# frozen_string_literal: true

# Load Rails environment
ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/application"

require "rspec/rails"
require "shoulda-matchers"
require "mail"
require "sent_emails"

# Configure Rails test environment
Rails.application.initialize!

# Require support files
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Configure fixture path
  config.fixture_paths = [File.expand_path("fixtures", __dir__)]

  # Use transactions for faster tests
  config.use_transactional_fixtures = true

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Include SentEmails test helpers for all specs
  config.include SentEmails::TestHelpers

  # Include Shoulda matchers in model specs
  config.include Shoulda::Matchers::ActiveModel, type: :model
  config.include Shoulda::Matchers::ActiveRecord, type: :model

  # Shoulda matchers
  Shoulda::Matchers.configure do |shoulda_config|
    shoulda_config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end

  # Configure database
  config.before(:suite) do
    # Create all tables
    ActiveRecord::Schema.verbose = false
    load File.expand_path("dummy/db/schema.rb", __dir__)
  end
end

