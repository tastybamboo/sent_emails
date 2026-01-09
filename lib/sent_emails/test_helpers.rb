# frozen_string_literal: true

module SentEmails
  # Test helpers for asserting on captured emails
  # 
  # @example Basic usage in RSpec
  #   include SentEmails::TestHelpers
  #   
  #   it "sends welcome email" do
  #     expect {
  #       UserMailer.welcome_email(user).deliver_now
  #     }.to have_sent_email(to: user.email)
  #   end
  #
  # @example Find and assert on email content
  #   email = find_sent_email(to: "user@example.com", subject: "Welcome")
  #   expect(email.html_body).to include("Welcome!")
  #
  # @example Clear emails between tests
  #   before { clear_sent_emails }
  module TestHelpers
    # Find emails by recipient
    # 
    # @param to [String] recipient email address
    # @return [ActiveRecord::Relation] matching emails
    def find_sent_emails(to:)
      Email.to(to)
    end

    # Find a single email by recipient and optional subject
    #
    # @param to [String] recipient email address
    # @param subject [String, Regexp, nil] subject to match
    # @return [Email] the matching email
    # @raise [ActiveRecord::RecordNotFound] if no email matches
    #
    # @example
    #   email = find_sent_email(to: "user@example.com", subject: "Welcome")
    def find_sent_email(to:, subject: nil)
      emails = find_sent_emails(to: to)
      
      if subject
        if subject.is_a?(Regexp)
          emails.detect { |e| e.subject&.match?(subject) } ||
            raise(ActiveRecord::RecordNotFound, "No email found to #{to} with subject matching #{subject.inspect}")
        else
          emails.find_by!(subject: subject)
        end
      else
        emails.first || raise(ActiveRecord::RecordNotFound, "No email found to #{to}")
      end
    end

    # Assert that an email was sent
    #
    # @param to [String] recipient email address
    # @param subject [String, Regexp, nil] subject to match
    # @return [Boolean] true if email was sent
    #
    # @example
    #   expect { UserMailer.welcome_email(user).deliver_now }
    #     .to have_sent_email(to: user.email, subject: "Welcome")
    def have_sent_email(to: nil, subject: nil)
      SentEmailMatcher.new(to: to, subject: subject)
    end

    # Count emails sent to a recipient
    #
    # @param to [String] recipient email address
    # @return [Integer] number of emails sent
    #
    # @example
    #   expect {
    #     3.times { UserMailer.notification(user).deliver_now }
    #   }.to change { count_sent_emails(to: user.email) }.by(3)
    def count_sent_emails(to: nil)
      if to
        find_sent_emails(to: to).count
      else
        Email.count
      end
    end

    # Clear all captured emails
    # Useful between tests to avoid cross-test pollution
    #
    # @example
    #   before { clear_sent_emails }
    def clear_sent_emails
      Event.delete_all
      Attachment.delete_all
      Email.delete_all
    end

    # Get the last email sent to a recipient
    #
    # @param to [String] recipient email address
    # @return [Email] the most recent email
    #
    # @example
    #   email = last_sent_email(to: "user@example.com")
    #   expect(email.subject).to eq("Welcome!")
    def last_sent_email(to:)
      find_sent_emails(to: to).order(created_at: :desc).first ||
        raise(ActiveRecord::RecordNotFound, "No email found to #{to}")
    end

    # Assert that no email was sent to a recipient
    #
    # @param to [String] recipient email address
    # @return [Boolean] true if no email was sent
    #
    # @example
    #   expect { UserMailer.welcome_email(user).deliver_now }
    #     .not_to have_sent_email(to: "other@example.com")
    def not_have_sent_email(to:)
      SentEmailMatcher.new(to: to, should_exist: false)
    end
  end

  # Matcher for RSpec: `expect { }.to have_sent_email(to: "...")`
  class SentEmailMatcher
    def initialize(to:, subject: nil, should_exist: true)
      @to = to
      @subject = subject
      @should_exist = should_exist
    end

    def supports_block_expectations?
      true
    end

    def matches?(proc)
      @emails_before = Email.count
      proc.call
      @emails_after = Email.count

      @email = find_matching_email if @emails_after > @emails_before

      if @should_exist
        @email.present?
      else
        @email.blank?
      end
    end

    def failure_message
      if @should_exist
        if @email.blank?
          "expected email to #{@to}#{subject_desc} to be sent, but it wasn't"
        else
          "expected email to #{@to}#{subject_desc} to match"
        end
      else
        "expected email to #{@to}#{subject_desc} not to be sent, but it was"
      end
    end

    def failure_message_when_negated
      "expected email to #{@to}#{subject_desc} not to be sent, but it was"
    end

    private

    def find_matching_email
      emails = Email.to(@to)
      
      if @subject
        if @subject.is_a?(Regexp)
          emails.detect { |e| e.subject&.match?(@subject) }
        else
          emails.find_by(subject: @subject)
        end
      else
        emails.order(created_at: :desc).first
      end
    end

    def subject_desc
      return "" unless @subject
      
      if @subject.is_a?(Regexp)
        " with subject matching #{@subject.inspect}"
      else
        " with subject #{@subject.inspect}"
      end
    end
  end
end
