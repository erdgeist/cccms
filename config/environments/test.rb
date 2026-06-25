Cccms::Application.configure do

  config.cache_classes = true

  # Log error messages when you accidentally call methods on nil.
  # config.whiny_nils = true  # removed in Rails 4

  config.action_controller.consider_all_requests_local = true
  config.action_controller.perform_caching             = false

  config.action_controller.allow_forgery_protection    = false

  config.action_mailer.delivery_method = :test

  config.active_support.deprecation = :log
  config.active_support.test_order  = :sorted

  config.active_record.raise_in_transactional_callbacks = true

  config.eager_load = false
  config.serve_static_files = true
  config.static_cache_control = "public, max-age=3600"
end
