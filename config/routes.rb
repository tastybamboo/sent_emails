# frozen_string_literal: true

SentEmails::Engine.routes.draw do
  root to: redirect("emails")

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
  post "webhooks/:provider", to: "webhooks#create", as: :webhook
end
