# frozen_string_literal: true

require "rails/generators"

module SentEmails
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs SentEmails: creates initializer and copies migrations"

      def copy_initializer
        template "initializer.rb", "config/initializers/sent_emails.rb"
      end

      def copy_migrations
        rake "sent_emails:install:migrations"
      end

      def add_route
        route 'mount SentEmails::Engine, at: "/admin/sent_emails"'
      end

      def show_post_install_message
        say ""
        say "SentEmails installed successfully!", :green
        say ""
        say "Next steps:"
        say "  1. Run migrations: rails db:migrate"
        say "  2. Include the helper in your ApplicationMailer:"
        say ""
        say "     class ApplicationMailer < ActionMailer::Base"
        say "       include SentEmails::MailerHelper"
        say "     end"
        say ""
        say "  3. Configure authentication in config/initializers/sent_emails.rb"
        say "  4. Visit /admin/sent_emails to view sent emails"
        say ""
      end
    end
  end
end
