# Put this in config/application.rb
require File.expand_path('../boot', __FILE__)

require 'rails/all'

Bundler.require(:default, Rails.env) if defined?(Bundler)

require 'action_controller'

module ActionController
  class Base
    def self.consider_all_requests_local=(val)
      # no-op: controlled via config.consider_all_requests_local in environment files
    end
  end
end

module Cccms
  class Application < Rails::Application
    config.autoload_paths += [config.root.join('lib')]
    config.encoding = 'utf-8'
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
  
    # Add additional load paths for your own custom dirs
    # config.load_paths += %W( #{RAILS_ROOT}/extras )
  
    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]
  
    # Allowed Tags
    # strong em b i p code pre tt samp kbd var sub sup dfn cite big small
    # address hr br div span h1 h2 h3 h4 h5 h6 ul ol li dt dd abbr
    # acronym a img blockquote del ins
  
    # Allowed Attributes:
    # href src width height alt cite datetime title class name xml:lang abbr))
  
    # Add tags to whitelist with:
    # config.action_view.sanitized_allowed_tags = 'table', 'tr', 'td'
  
    # Add attributes to whitelist with:
    # config.action_view.sanitized_allowed_attributes = 'id', 'class', 'style'
  
    # Activate observers that should always be running
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer
  
    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names.
    config.time_zone = 'Berlin'
  
    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
    config.i18n.default_locale = :de

    config.filter_parameters += [:password, :password_confirmation]
  end
end
