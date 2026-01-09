# frozen_string_literal: true

module SentEmails
  # Legacy helper module for mailers.
  # Email capture is now handled automatically via ActionMailerHook prepended
  # to ActionMailer::MessageDelivery. This module is kept for backwards
  # compatibility but no longer performs any capture logic.
  module MailerHelper
    extend ActiveSupport::Concern

    # No-op: capture is handled by ActionMailerHook
  end
end
