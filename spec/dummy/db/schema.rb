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
    t.datetime :created_at, null: false
    t.datetime :updated_at, null: false

    t.index [:message_id], unique: true
    t.index [:status]
    t.index [:created_at]
  end

  create_table :sent_emails_attachments, id: :bigint, force: :cascade do |t|
    t.bigint :email_id, null: false
    t.string :filename
    t.string :content_type
    t.integer :byte_size
    t.binary :blob
    t.datetime :created_at, null: false
    t.datetime :updated_at, null: false

    t.foreign_key :sent_emails_emails, column: :email_id
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
