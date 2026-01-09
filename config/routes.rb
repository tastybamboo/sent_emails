# frozen_string_literal: true

SentEmails::Engine.routes.draw do
  root to: redirect("emails")

  resources :emails, only: [:index, :show, :destroy] do
    member do
      post :resend
    end
  end

  # Webhook routes - provider is determined by route matching, not defaults
  # The actual provider handling is configured in initializers
  post "webhooks/:provider", to: "webhooks#create", as: :webhook
end
