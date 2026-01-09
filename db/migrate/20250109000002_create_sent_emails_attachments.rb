# frozen_string_literal: true

class CreateSentEmailsAttachments < ActiveRecord::Migration[7.0]
  def change
    create_table :sent_emails_attachments, id: :bigint do |t|
      t.references :email, null: false, foreign_key: {to_table: :sent_emails_emails}, type: :bigint
      t.string :filename, null: false
      t.string :content_type
      t.integer :byte_size
      t.binary :blob

      t.timestamps
    end
  end
end
