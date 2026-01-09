# frozen_string_literal: true

SentEmails::Engine.routes.draw do
  resources :emails, only: [:index, :show, :destroy] do
    member do
      post :resend
    end
  end

  post "webhooks/:provider", to: "webhooks#create", as: :webhook
end
