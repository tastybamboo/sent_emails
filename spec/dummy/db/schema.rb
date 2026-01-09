# frozen_string_literal: true

ActiveRecord::Schema.define(version: 0) do
  create_table :sent_emails_emails, id: :bigint, force: :cascade do |t|
    t.string :message_id
    t.string :mailer
    t.string :action
    t.string :template_path
    t.json :mailer_params
    t.string :delivery_method
    t.string :provider
    t.json :delivery_settings
    t.string :from_address, null: false
    t.json :to_addresses, null: false
    t.json :cc_addresses
    t.json :bcc_addresses
    t.string :subject
    t.text :text_body
    t.text :html_body
    t.json :headers
    t.string :status, default: "pending"
    t.datetime :sent_at
    t.datetime :delivered_at

    # Cached latest event (migration 5)
    t.string :latest_event_type
    t.datetime :latest_event_at

    # Context capture (migration 6)
    t.string :environment
    t.string :delivery_type
    t.string :process_type
    t.string :request_id
    t.string :user_agent
    t.string :remote_ip
    t.string :ruby_version
    t.string :rails_version
    t.json :context

    # Archive support (migration 7)
    t.datetime :archived_at

    # Delivery tracking (migration 10)
    t.string :delivery_token

    t.datetime :created_at, null: false
    t.datetime :updated_at, null: false

    t.index [:message_id], unique: true
    t.index [:status]
    t.index [:created_at]
    t.index [:archived_at], where: "archived_at IS NULL", name: "index_sent_emails_emails_active"
    t.index [:delivery_token], where: "delivery_token IS NOT NULL"
  end

  create_table :sent_emails_attachments, id: :bigint, force: :cascade do |t|
    t.bigint :email_id, null: false
    t.string :filename
    t.string :content_type
    t.integer :byte_size
    t.binary :blob
    t.string :content_id
    t.boolean :inline, default: false
    t.string :content_hash
    t.datetime :created_at, null: false
    t.datetime :updated_at, null: false

    t.foreign_key :sent_emails_emails, column: :email_id
    t.index [:content_hash]
  end

  create_table :sent_emails_events, id: :bigint, force: :cascade do |t|
    t.bigint :email_id, null: false
    t.string :event_type
    t.string :provider
    t.json :payload
    t.datetime :occurred_at
    t.datetime :created_at, null: false
    t.datetime :updated_at, null: false

    t.foreign_key :sent_emails_emails, column: :email_id
    t.index [:email_id]
    t.index [:event_type]
  end
end
