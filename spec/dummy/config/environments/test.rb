# frozen_string_literal: true

Rails.application.configure do
  config.eager_load = false
  config.cache_classes = true
  config.consider_all_requests_local = true
  config.action_controller.allow_forgery_protection = false
  config.active_job.queue_adapter = :test
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = true
end
