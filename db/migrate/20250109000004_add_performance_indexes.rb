# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[7.0]
  def change
    # Index for searching by recipient (PostgreSQL-specific)
    if connection.adapter_name.downcase == "postgresql"
      add_index :sent_emails_emails, :to_addresses, using: :gin, if_not_exists: true
      add_index :sent_emails_emails, :cc_addresses, using: :gin, if_not_exists: true
      add_index :sent_emails_emails, :bcc_addresses, using: :gin, if_not_exists: true
    end

    # Index for subject searches
    add_index :sent_emails_emails, :subject, if_not_exists: true

    # Compound index for status + created_at (common filter + sort)
    add_index :sent_emails_emails, [:status, :created_at], if_not_exists: true

    # Index for event queries (very common in show view)
    add_index :sent_emails_events, :email_id, if_not_exists: true

    # Compound index for email_id + occurred_at (latest event queries)
    add_index :sent_emails_events, [:email_id, :occurred_at], if_not_exists: true
  end
end
