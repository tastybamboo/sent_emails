# frozen_string_literal: true

class AddContentIdToAttachments < ActiveRecord::Migration[7.0]
  def change
    add_column :sent_emails_attachments, :content_id, :string
    add_column :sent_emails_attachments, :inline, :boolean, default: false
  end
end
