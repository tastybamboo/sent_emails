# frozen_string_literal: true

source "https://rubygems.org"

gemspec

rails_version = ENV.fetch("RAILS_VERSION", "8.1")
gem "rails", "~> #{rails_version}.0"

gem "irb"
gem "rake", "~> 13.0"

# Testing — rspec-rails 8.x requires Rails >= 7.2
if Gem::Version.new(rails_version) >= Gem::Version.new("7.2")
  gem "rspec-rails", "~> 8.0"
else
  gem "rspec-rails", "~> 7.0"
end

# shoulda-matchers 8.x requires Ruby >= 3.3
if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.3")
  gem "shoulda-matchers", "~> 8.0"
else
  gem "shoulda-matchers", "~> 6.0"
end

# Linting
gem "standard", require: false
gem "standard-rails", require: false

# Development — Rails 7.0 requires sqlite3 ~> 1.4; 7.1+ works with 2.x
if Gem::Version.new(rails_version) < Gem::Version.new("7.1")
  gem "sqlite3", "~> 1.4"
else
  gem "sqlite3"
end

# Postgres-specific scopes (Email.to, Email.search) only run against the
# `using_postgresql?` branch when the dummy app is configured to use it —
# see spec/dummy/config/database.yml and DB=postgresql in CI.
gem "pg", "~> 1.6"
