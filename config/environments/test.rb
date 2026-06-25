Cccms::Application.configure do

  config.cache_classes = true

  config.action_controller.consider_all_requests_local = true
  config.action_controller.perform_caching             = false

  config.action_controller.allow_forgery_protection    = false

  config.action_mailer.delivery_method = :test

  config.active_support.deprecation = :log
  config.active_support.test_order  = :sorted

  config.eager_load = false
  config.public_file_server.enabled = true
  config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=3600' }
  config.assets.compile = true
end
