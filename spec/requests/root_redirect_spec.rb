# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Engine root redirect", type: :request do
  it "redirects to emails index under the engine mount path" do
    get "/admin/sent_emails"

    expect(response).to have_http_status(:redirect)
    expect(response.location).to eq("http://www.example.com/admin/sent_emails/emails")
  end
end
