# SentEmails

A Rails engine that captures sent emails with full content, tracks delivery status via webhooks, and provides a UI for viewing and resending emails.

## Features

- **Full email capture** - Subject, body (text/HTML), headers, attachments
- **Rails context** - Mailer class, action name, template path, parameters passed
- **Delivery details** - Provider used, delivery method, SMTP settings
- **Delivery tracking** - Webhook integration with Mailpace, Mailgun, and SendGrid (more providers coming)
- **Event timeline** - See queued, delivered, bounced, and other events
- **Resend emails** - One-click resend from the UI
- **Standalone UI** - Self-contained Tailwind CSS admin panel

## Installation

Add this line to your application's Gemfile:

```ruby
gem "sent_emails"
```

Then run:

```bash
bundle install
rails generate sent_emails:install
rails db:migrate
```

## Database Support

The gem works with any Rails-supported database, with optimizations for PostgreSQL:

### PostgreSQL (Recommended)
- **JSONB columns** for email metadata (mailer_params, delivery_settings, headers, payload)
- **Array columns** for recipient lists (to_addresses, cc_addresses, bcc_addresses)
- **Native array operators** - `ANY()` for fast recipient searches
- **GIN indexes** on array columns for optimal performance at scale
- **ILIKE operator** for case-insensitive text searches

### SQLite, MySQL, MariaDB
- **JSON columns** for metadata
- **JSON columns** for recipient lists
- **LIKE operator** for text searches (case-insensitive in SQLite)
- All queries automatically adapted to use JSON functions instead of arrays

The gem detects your database at migration time and generates appropriate schema. No configuration needed.

## Configuration

### Include the MailerHelper

Add the helper to your `ApplicationMailer`:

```ruby
class ApplicationMailer < ActionMailer::Base
  include SentEmails::MailerHelper

  default from: "notifications@example.com"
  layout "mailer"
end
```

### Configure Authentication

Edit `config/initializers/sent_emails.rb` to protect the UI:

```ruby
SentEmails.configure do |config|
  # With Devise
  config.authentication_method = ->(controller) {
    controller.authenticate_admin!
  }

  # With HTTP Basic Auth
  config.authentication_method = ->(controller) {
    controller.authenticate_or_request_with_http_basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, ENV["ADMIN_USER"]) &&
        ActiveSupport::SecurityUtils.secure_compare(password, ENV["ADMIN_PASSWORD"])
    end
  }
end
```

### Configure Webhook Provider (Mailpace)

To receive delivery status updates (delivered, bounced, spam, etc.), configure Mailpace webhook verification:

```ruby
SentEmails.configure do |config|
  config.provider :mailpace do |p|
    p.public_key = Rails.application.credentials.dig(:mailpace, :webhook_public_key)
  end
end
```

**Important:** Without this configuration, all incoming webhooks will return **401 Unauthorized** because the gem cannot verify the Ed25519 signature.

#### Getting Your Webhook Public Key

1. Log in to [Mailpace](https://app.mailpace.com)
2. Go to **Organization Settings** → **Webhooks**
3. Copy the **Public Key** (a 64-character hex string)
4. Add it to your Rails credentials:

```bash
rails credentials:edit
```

```yaml
mailpace:
  server_token: "your_smtp_token"
  webhook_public_key: "your_64_char_hex_public_key"
```

#### Configuring the Webhook URL in Mailpace

Set your webhook URL in Mailpace to:

```
https://yourapp.com/admin/sent_emails/webhooks/mailpace
```

Or if you've mounted webhooks separately (see [Separate Webhook Path](#separate-webhook-path)):

```
https://yourapp.com/webhooks/sent_emails/mailpace
```

### Configure Webhook Provider (SendGrid)

To receive SendGrid delivery status updates, enable **Signed Event Webhook** and configure the verification key:

```ruby
SentEmails.configure do |config|
  config.provider :sendgrid do |p|
    p.verification_key = Rails.application.credentials.dig(:sendgrid, :webhook_verification_key)
  end
end
```

#### Getting Your Verification Key

1. Log in to [SendGrid](https://app.sendgrid.com)
2. Go to **Settings** → **Mail Settings** → **Event Webhooks**
3. Create or edit a webhook, enable **Signed Event Webhook**, and save
4. Copy the **Verification Key** and add it to your Rails credentials

#### Configuring the Webhook URL in SendGrid

```
https://yourapp.com/admin/sent_emails/webhooks/sendgrid
```

Or with a separate webhook mount:

```
https://yourapp.com/webhooks/sent_emails/sendgrid
```

#### Webhook Events

SendGrid sends batched event arrays which are automatically processed:

| SendGrid Event | SentEmails Status |
|----------------|-------------------|
| `processed` | `sent` |
| `delivered` | `delivered` |
| `deferred` | `deferred` |
| `bounce` | `bounced` (`soft_bounced` when `type` is `blocked`) |
| `dropped` | `rejected` |
| `open` | `opened` |
| `click` | `clicked` |
| `spamreport` | `spam` |
| `unsubscribe` / `group_unsubscribe` | `unsubscribed` |

Events are matched to captured emails via the `smtp-id` field (the email Message-ID).

#### Signature Failure Reporting

By default, failed webhook signature verifications are logged as warnings. To report them to your error tracking service, configure the `on_signature_failure` callback:

```ruby
SentEmails.configure do |config|
  config.on_signature_failure = ->(provider, request) {
    Appsignal.send_error(
      SentEmails::Error.new("Webhook signature verification failed for #{provider}")
    )
  }
end
```

The callback receives the provider name (String) and the `ActionDispatch::Request` object.

#### Webhook Events

Mailpace sends these events which are automatically processed:

| Mailpace Event | SentEmails Status |
|----------------|-------------------|
| `email.queued` | `queued` |
| `email.delivered` | `delivered` |
| `email.deferred` | `deferred` |
| `email.bounced` | `bounced` |
| `email.spam` | `spam` |

## Usage

### Viewing Emails

Visit `/admin/sent_emails` to see all sent emails. You can:

- Search by recipient or subject
- Filter by status
- View email content (HTML and text)
- See Rails context (mailer, action, parameters)
- See delivery details (provider, SMTP settings)
- View event timeline from webhooks
- Resend emails

### Email Statuses

| Status | Description |
|--------|-------------|
| `pending` | Email queued locally |
| `queued` | Accepted by provider |
| `sent` | Handed off to provider |
| `delivered` | Confirmed delivered |
| `deferred` | Temporarily delayed |
| `bounced` | Hard bounce (permanent) |
| `soft_bounced` | Soft bounce (temporary) |
| `failed` | General failure |
| `spam` | Marked as spam |
| `rejected` | Rejected by provider |

### Attachment Storage

Configure how attachments are stored:

```ruby
SentEmails.configure do |config|
  # Store attachment content in database (default)
  config.attachment_storage = :database

  # Only store metadata (filename, size, content type)
  config.attachment_storage = :metadata_only

  # Maximum size to store in database (larger attachments get metadata only)
  config.max_attachment_size = 10.megabytes
end
```

## Routes

The engine mounts at `/admin/sent_emails` by default. You can change this in your `config/routes.rb`:

```ruby
mount SentEmails::Engine, at: "/emails"
```

Available routes:

| Path | Description |
|------|-------------|
| `GET /admin/sent_emails` | Email list |
| `GET /admin/sent_emails/:id` | Email detail |
| `POST /admin/sent_emails/:id/resend` | Resend email |
| `DELETE /admin/sent_emails/:id` | Delete email |
| `POST /admin/sent_emails/webhooks/:provider` | Webhook endpoint |

### Separate Webhook Path

By default, webhooks are mounted within the engine. If you want webhooks at a different path (e.g., to keep `/admin` routes protected while webhooks remain publicly accessible), you can mount them separately:

```ruby
# config/initializers/sent_emails.rb
SentEmails.configure do |config|
  config.mount_webhooks_in_engine = false
  # ... other config
end
```

```ruby
# config/routes.rb
mount SentEmails::Engine, at: "/admin/sent_emails"
SentEmails.mount_webhook_routes(self, at: "/webhooks/sent_emails")
```

This gives you:

- UI at `/admin/sent_emails` (can be protected by admin authentication)
- Webhooks at `/webhooks/sent_emails/:provider` (publicly accessible for email providers)

Set your webhook URL in Mailpace to:

```
https://yourapp.com/webhooks/sent_emails/mailpace
```

## Supported Providers

### Currently Supported

- **Mailpace** - Ed25519 signature verification
- **Mailgun** - HMAC-SHA256 signature verification
- **SendGrid** - ECDSA (Signed Event Webhook) signature verification
- **Postmark** - HMAC-SHA256 signature verification

### Planned

- Amazon SES

## Development

After checking out the repo:

```bash
bin/setup
bundle exec rspec
bundle exec standardrb
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tastybamboo/sent_emails.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
