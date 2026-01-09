# frozen_string_literal: true

class AddContentHashToAttachments < ActiveRecord::Migration[7.0]
  def change
    add_column :sent_emails_attachments, :content_hash, :string

    # Index for deduplication lookups
    add_index :sent_emails_attachments, :content_hash
  end
end
