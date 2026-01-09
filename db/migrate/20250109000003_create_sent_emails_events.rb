# frozen_string_literal: true

class CreateSentEmailsEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :sent_emails_events, id: :bigint do |t|
      t.references :email, null: false, foreign_key: {to_table: :sent_emails_emails}, type: :bigint
      t.string :event_type, null: false
      t.string :provider
      t.json :payload, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :sent_emails_events, [:email_id, :event_type]
    add_index :sent_emails_events, :occurred_at
  end
end
