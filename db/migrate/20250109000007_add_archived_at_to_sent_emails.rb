# frozen_string_literal: true

class AddArchivedAtToSentEmails < ActiveRecord::Migration[7.0]
  def change
    add_column :sent_emails_emails, :archived_at, :datetime, null: true

    add_index :sent_emails_emails, :archived_at, where: "archived_at IS NULL", name: "index_sent_emails_emails_active"
  end
end
