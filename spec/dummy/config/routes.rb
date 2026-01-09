# frozen_string_literal: true

Rails.application.routes.draw do
  mount SentEmails::Engine, at: "/admin/sent_emails"
end
