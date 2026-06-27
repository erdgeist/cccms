require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Cccms
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])
    Rails.autoloaders.main.ignore(
      Rails.root.join('lib/chaos_importer.rb'),
      Rails.root.join('lib/update_importer.rb')
    )

    config.time_zone = 'Berlin'

    config.i18n.default_locale = :de
    config.i18n.fallbacks = { en: [:en, :de] }

    config.filter_parameters += [:password, :password_confirmation]
    config.active_storage.variant_processor = :disabled
  end
end
