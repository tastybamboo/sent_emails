# frozen_string_literal: true

class AddContextToSentEmails < ActiveRecord::Migration[7.0]
  def change
    add_column :sent_emails_emails, :environment, :string, if_not_exists: true
    add_column :sent_emails_emails, :delivery_type, :string, if_not_exists: true  # deliver_now or deliver_later
    add_column :sent_emails_emails, :process_type, :string, if_not_exists: true  # web, console, runner, job
    add_column :sent_emails_emails, :request_id, :string, if_not_exists: true
    add_column :sent_emails_emails, :user_agent, :string, if_not_exists: true
    add_column :sent_emails_emails, :remote_ip, :string, if_not_exists: true
    add_column :sent_emails_emails, :ruby_version, :string, if_not_exists: true
    add_column :sent_emails_emails, :rails_version, :string, if_not_exists: true
    add_column :sent_emails_emails, :context, :json, default: {}, if_not_exists: true

    add_index :sent_emails_emails, :environment, if_not_exists: true
    add_index :sent_emails_emails, :process_type, if_not_exists: true
    add_index :sent_emails_emails, :delivery_type, if_not_exists: true
  end
end
