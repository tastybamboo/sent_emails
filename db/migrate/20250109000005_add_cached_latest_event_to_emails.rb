# frozen_string_literal: true

class AddCachedLatestEventToEmails < ActiveRecord::Migration[7.0]
  def change
    add_column :sent_emails_emails, :latest_event_type, :string, if_not_exists: true
    add_column :sent_emails_emails, :latest_event_at, :datetime, if_not_exists: true

    # Populate existing records
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE sent_emails_emails
          SET latest_event_type = subquery.event_type,
              latest_event_at = subquery.occurred_at
          FROM (
            SELECT DISTINCT ON (email_id) email_id, event_type, occurred_at
            FROM sent_emails_events
            ORDER BY email_id, occurred_at DESC
          ) AS subquery
          WHERE sent_emails_emails.id = subquery.email_id;
        SQL
      end
    end
  end
end
