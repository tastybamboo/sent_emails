# SentEmails Test Helpers

The SentEmails gem provides comprehensive test helpers for asserting on captured emails in your tests.

## Installation

The helpers are automatically included in your RSpec configuration when you use the gem:

```ruby
# spec/rails_helper.rb
config.include SentEmails::TestHelpers
```

## Available Helpers

### Block Matcher: `have_sent_email`

Assert that an email was sent within a block:

```ruby
expect {
  UserMailer.welcome_email(user).deliver_now
}.to have_sent_email(to: user.email)
```

**With subject matching (exact):**
```ruby
expect {
  UserMailer.welcome_email(user).deliver_now
}.to have_sent_email(to: user.email, subject: "Welcome to CharityTools!")
```

**With subject matching (regex):**
```ruby
expect {
  UserMailer.welcome_email(user).deliver_now
}.to have_sent_email(to: user.email, subject: /Welcome/)
```

### `find_sent_email`

Find a specific email by recipient and optional subject:

```ruby
# Find by recipient only
email = find_sent_email(to: "user@example.com")

# Find by recipient and exact subject
email = find_sent_email(to: "user@example.com", subject: "Welcome!")

# Find by recipient and subject regex
email = find_sent_email(to: "user@example.com", subject: /Welcome/)

# Assert on content
expect(email.html_body).to include("Welcome message")
expect(email.from_address).to eq("noreply@charitytools.co.uk")
```

### `find_sent_emails`

Get all emails sent to a recipient:

```ruby
emails = find_sent_emails(to: "user@example.com")
expect(emails.count).to eq(2)
expect(emails.map(&:subject)).to include("Notification 1", "Notification 2")
```

### `last_sent_email`

Get the most recent email sent to a recipient:

```ruby
UserMailer.notification(user).deliver_now
UserMailer.confirmation(user).deliver_now

email = last_sent_email(to: user.email)
expect(email.subject).to eq("Confirmation instructions")
```

### `count_sent_emails`

Count emails sent to a recipient or all emails:

```ruby
# Count all emails to a recipient
expect {
  3.times { UserMailer.notification(user).deliver_now }
}.to change { count_sent_emails(to: user.email) }.by(3)

# Count all emails
expect {
  UserMailer.welcome(user1).deliver_now
  UserMailer.welcome(user2).deliver_now
}.to change { count_sent_emails }.by(2)
```

### `clear_sent_emails`

Clear all captured emails (useful for test isolation):

```ruby
before { clear_sent_emails }

it "sends welcome email" do
  expect {
    UserMailer.welcome(user).deliver_now
  }.to have_sent_email(to: user.email)
  
  # Only one email in the database, no cross-test pollution
  expect(count_sent_emails).to eq(1)
end
```

### `not_have_sent_email`

Assert that no email was sent to a recipient:

```ruby
expect {
  # Some action that should NOT send email
}.not_to have_sent_email(to: "invalid@example.com")
```

## Email Object Properties

Once you have an email, you can inspect its properties:

```ruby
email = find_sent_email(to: "user@example.com")

# Content
email.subject           # "Welcome to CharityTools!"
email.html_body         # "<p>Welcome...</p>"
email.text_body         # "Welcome..."
email.from_address      # "noreply@charitytools.co.uk"

# Recipients
email.to_addresses      # ["user@example.com"]
email.cc_addresses      # ["cc@example.com"]
email.bcc_addresses     # ["bcc@example.com"]
email.all_recipients    # All of the above combined

# Context
email.mailer            # "UserMailer"
email.action            # "welcome_email"
email.template_identifier # "user_mailer/welcome_email"
email.mailer_params     # { user_id: 1 }

# Delivery
email.status            # "sent" (or other status from webhooks)
email.provider          # "test", "mailpace", etc.
email.delivery_method   # "smtp", "test", etc.
email.sent_at           # <Time object>
email.delivered_at      # <Time object> (when available from webhooks)

# Attachments
email.attachments       # Collection of attachments
email.attachments.map(&:filename)

# Events (from webhooks)
email.events            # Event timeline
email.latest_event      # Most recent event
```

## Example Spec

```ruby
# spec/mailers/user_mailer_spec.rb
require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  before { clear_sent_emails }

  describe "confirmation_instructions" do
    let(:user) { create(:user) }

    it "sends confirmation email" do
      expect {
        UserMailer.confirmation_instructions(user, "token").deliver_now
      }.to have_sent_email(to: user.email, subject: /Confirmation/)
    end

    it "includes confirmation token" do
      UserMailer.confirmation_instructions(user, "test-token").deliver_now

      email = find_sent_email(to: user.email)
      expect(email.html_body).to include("test-token")
    end
  end

  describe "welcome_email" do
    let(:user) { create(:user, email: "alice@example.com") }

    it "sends to correct address" do
      expect {
        UserMailer.welcome_email(user).deliver_now
      }.to have_sent_email(to: "alice@example.com")
    end

    it "personalizes with user name" do
      user.update(first_name: "Alice")

      UserMailer.welcome_email(user).deliver_now

      email = find_sent_email(to: user.email)
      expect(email.html_body).to include("Alice")
    end
  end
end
```

## Why Clear Emails Between Tests?

SentEmails captures emails to the database. To avoid cross-test pollution:

```ruby
before { clear_sent_emails }
```

This ensures each test starts with a clean database and assertions are specific to that test's actions.

## Transaction Isolation Note

If you use `config.use_transactional_fixtures = true` (the default), captured emails will be rolled back after each test. To keep test emails:

```ruby
# config/environments/test.rb
config.use_transactional_fixtures = false

# Then use `database_cleaner` or manually call `clear_sent_emails`
```

Most tests won't need this - the default behavior is fine for asserting emails in the test.

## Testing with Different Delivery Methods

The helpers work with all delivery methods:

```ruby
# Test environment (immediate delivery)
UserMailer.welcome(user).deliver_now

# Async delivery
expect {
  UserMailer.welcome(user).deliver_later
}.to have_sent_email(to: user.email)  # Captured immediately

# In production (with Mailpace)
# Still captured to database, plus webhook events appear in email.events
```

## Integration with Factories

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    
    trait :with_confirmation_email do
      after(:create) do |user|
        UserMailer.confirmation_instructions(user, "token").deliver_now
      end
    end
  end
end

# In your spec
user = create(:user, :with_confirmation_email)
expect(count_sent_emails(to: user.email)).to eq(1)
```
