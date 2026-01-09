# frozen_string_literal: true

module SentEmails
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :exception

    before_action :authenticate!

    private

    def authenticate!
      auth_method = SentEmails.configuration.authentication_method
      return unless auth_method

      if auth_method.respond_to?(:call)
        auth_method.call(self)
      elsif auth_method.is_a?(Symbol) && respond_to?(auth_method, true)
        send(auth_method)
      end
    end
  end
end
