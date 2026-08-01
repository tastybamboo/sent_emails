# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Emails UI", type: :request do
  describe "GET /admin/sent_emails/emails" do
    it "lists active emails" do
      email = create_email(subject: "Welcome")
      archived = create_email(subject: "Archived subject", archived_at: 1.hour.ago)

      get "/admin/sent_emails/emails"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(email.subject)
      expect(response.body).not_to include(archived.subject)
    end

    it "filters by status" do
      delivered = create_email(subject: "Delivered mail", status: :delivered)
      create_email(subject: "Pending mail", status: :pending)

      get "/admin/sent_emails/emails", params: {status: "delivered"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(delivered.subject)
      expect(response.body).not_to include("Pending mail")
    end

    it "searches by subject" do
      match = create_email(subject: "Unique search subject")
      create_email(subject: "Something else")

      get "/admin/sent_emails/emails", params: {q: "Unique search"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(match.subject)
      expect(response.body).not_to include("Something else")
    end
  end

  describe "GET /admin/sent_emails/emails/archived" do
    it "lists archived emails" do
      active = create_email(subject: "Still active")
      archived = create_email(subject: "In the archive", archived_at: 1.hour.ago)

      get "/admin/sent_emails/emails/archived"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(archived.subject)
      expect(response.body).not_to include(active.subject)
    end
  end

  describe "GET /admin/sent_emails/emails/:id" do
    it "shows an email" do
      email = create_email(subject: "Detail view", text_body: "Hello there")

      get "/admin/sent_emails/emails/#{email.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Detail view")
      expect(response.body).to include("Hello there")
    end

    it "redirects when the email is missing" do
      get "/admin/sent_emails/emails/0"

      expect(response).to redirect_to("/admin/sent_emails/emails")
      follow_redirect!
      expect(response.body).to include("Email not found")
    end
  end

  describe "POST /admin/sent_emails/emails/:id/archive" do
    it "archives the email" do
      email = create_email

      post "/admin/sent_emails/emails/#{email.id}/archive"

      expect(response).to redirect_to("/admin/sent_emails/emails")
      expect(email.reload).to be_archived
    end
  end

  describe "POST /admin/sent_emails/emails/:id/unarchive" do
    it "restores an archived email" do
      email = create_email(archived_at: 1.hour.ago)

      post "/admin/sent_emails/emails/#{email.id}/unarchive"

      expect(response).to redirect_to("/admin/sent_emails/emails/#{email.id}")
      expect(email.reload).not_to be_archived
    end
  end

  describe "POST /admin/sent_emails/emails/:id/resend" do
    it "queues a resend when mailer information is present" do
      email = create_email(mailer: "TestMailer", action: "simple_notification", mailer_params: {})

      expect {
        post "/admin/sent_emails/emails/#{email.id}/resend"
      }.to have_enqueued_mail(TestMailer, :simple_notification)

      expect(response).to redirect_to("/admin/sent_emails/emails/#{email.id}")
      follow_redirect!
      expect(response.body).to include("Email queued for resend")
    end

    it "alerts when mailer information is missing" do
      email = create_email(mailer: nil, action: nil)

      post "/admin/sent_emails/emails/#{email.id}/resend"

      expect(response).to redirect_to("/admin/sent_emails/emails/#{email.id}")
      follow_redirect!
      expect(response.body).to include("Unable to resend")
    end
  end
end
