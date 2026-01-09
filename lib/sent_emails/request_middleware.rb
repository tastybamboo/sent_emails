# frozen_string_literal: true

module SentEmails
  # Rack middleware that captures the current request in thread-local storage.
  # This allows the ActionMailer hook to access request context (user_agent,
  # remote_ip, request_id) when emails are sent from controller actions.
  class RequestMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      Thread.current[:__sent_emails_request] = ActionDispatch::Request.new(env)
      @app.call(env)
    ensure
      Thread.current[:__sent_emails_request] = nil
    end
  end
end
