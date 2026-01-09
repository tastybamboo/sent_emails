# frozen_string_literal: true

require_relative "lib/sent_emails/version"

Gem::Specification.new do |spec|
  spec.name = "sent_emails"
  spec.version = SentEmails::VERSION
  spec.authors = ["James Inman", "Otaina Limited"]
  spec.email = ["hello@tastybamboo.io"]

  spec.summary = "Track and view all sent emails in your Rails application"
  spec.description = "A Rails engine that captures sent emails with full content, tracks delivery status via webhooks, and provides a UI for viewing and resending emails."
  spec.homepage = "https://github.com/tastybamboo/sent_emails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/tastybamboo/sent_emails"
  spec.metadata["changelog_uri"] = "https://github.com/tastybamboo/sent_emails/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "ed25519"
end
