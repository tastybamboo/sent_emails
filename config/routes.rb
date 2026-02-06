# frozen_string_literal: true

SentEmails::Engine.routes.draw do
  root to: redirect { |_params, request| "#{request.script_name}/emails" }

  resources :emails, only: [:index, :show] do
    collection do
      get :archived
    end
    member do
      post :resend
      post :archive
      post :unarchive
    end
  end

  # Webhook routes - provider is determined by route matching, not defaults
  # The actual provider handling is configured in initializers
  #
  # The constraint checks mount_webhooks_in_engine? at request time, allowing
  # users to disable engine webhooks via config and mount them separately at
  # a different path (e.g., /webhooks/sent_emails instead of /admin/sent_emails/webhooks)
  post "webhooks/:provider",
    to: "webhooks#create",
    as: :webhook,
    constraints: ->(_request) { SentEmails.mount_webhooks_in_engine? }
end
