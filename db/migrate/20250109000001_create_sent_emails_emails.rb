# frozen_string_literal: true

class CreateSentEmailsEmails < ActiveRecord::Migration[7.0]
  def change
    create_table :sent_emails_emails, id: :bigint do |t|
      t.string :message_id

      # Rails context
      t.string :mailer
      t.string :action
      t.string :template_path
      t.json :mailer_params, default: {}

      # Delivery mechanism
      t.string :delivery_method
      t.string :provider
      t.json :delivery_settings, default: {}

      # Email content
      t.string :from_address, null: false
      t.json :to_addresses, null: false
      t.json :cc_addresses
      t.json :bcc_addresses
      t.string :subject
      t.text :text_body
      t.text :html_body
      t.json :headers, default: {}

      # Status tracking
      t.string :status, default: "pending", null: false
      t.datetime :sent_at
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :sent_emails_emails, :message_id, unique: true
    add_index :sent_emails_emails, :status
    add_index :sent_emails_emails, :created_at
    add_index :sent_emails_emails, :mailer
  end
end
