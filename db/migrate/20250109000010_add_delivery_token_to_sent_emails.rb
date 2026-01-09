# frozen_string_literal: true

class AddDeliveryTokenToSentEmails < ActiveRecord::Migration[7.0]
  def change
    add_column :sent_emails_emails, :delivery_token, :string

    # Index for fast lookups when matching queued emails
    add_index :sent_emails_emails, [:delivery_token], where: "delivery_token IS NOT NULL"
  end
end
