source 'https://rubygems.org'

ruby '3.2.11'

# ── Core framework ────────────────────────────────────────────────────────────

gem 'rails',      '~> 8.1'
gem 'rails-i18n', '~> 8.0'  # AR error messages and date formats for :de locale

# concurrent-ruby 1.3 ships with Rails 8 but has a known incompatibility with
# some versions of Zeitwerk unless pinned. Remove once upstream resolves it.
gem 'concurrent-ruby', '~> 1.3'

gem 'puma'               # default Rails 8 server; used in development only
gem 'unicorn', '~> 6.1'  # production server (FreeBSD jail, managed via rc.d)

# ── Database ──────────────────────────────────────────────────────────────────

gem 'pg', '~> 1.5'

# ── Asset pipeline ────────────────────────────────────────────────────────────

gem 'sprockets-rails'
gem 'sass-rails',   '~> 6.0'
gem 'coffee-rails', '~> 4.0'
gem 'uglifier',     '>= 1.0.3'

gem 'jquery-rails'     # provides jQuery via asset pipeline (admin only)
gem 'jquery-ui-rails'  # provides jQuery UI via asset pipeline (admin only)

# TinyMCE 8 via asset pipeline; replaces vendored TinyMCE 3 in public/javascripts.
# Note: TinyMCE 7+ is GPL-licensed.
gem 'tinymce-rails', '~> 8.3'

# ── Model layer ───────────────────────────────────────────────────────────────

gem 'globalize',      '~> 7.0'    # translated model attributes (Page title/abstract/body)
gem 'acts_as_list'                # page revision ordering
gem 'will_paginate',  '~> 3.0'

# Pinned to git until a release widens the activerecord < 8.1 ceiling.
# Both gems work correctly on Rails 8.1; the gemspec constraint is overly conservative.
# Revisit when acts-as-taggable-on > 12.x or awesome_nested_set > 3.8.0 is released.
gem 'acts-as-taggable-on',
    git:    'https://github.com/mbleigh/acts-as-taggable-on.git',
    branch: 'master'
gem 'awesome_nested_set',
    git:    'https://github.com/collectiveidea/awesome_nested_set.git',
    branch: 'main'

# ── XML / parsing ─────────────────────────────────────────────────────────────

gem 'libxml-ruby', '~> 5.0', require: 'xml'  # body link rewriting in Page model
gem 'nokogiri',    '~> 1.18'

# ── Operational ───────────────────────────────────────────────────────────────

gem 'exception_notification', '~> 4.5'

# chaos_calendar: C extension wrapping libical for the public events calendar.
# Pinned to custom branch; includes FreeBSD 15.1 / libical 3.x header path fix
# and icaltime_from_timet_with_zone floating-time semantics.
gem 'chaos_calendar',
    git:     'https://github.com/erdgeist/chaoscalendar.git',
    branch:  'erdgeist-ruby1.9',
    require: 'chaos_calendar'

# ── Test ──────────────────────────────────────────────────────────────────────

group :test do
  gem 'test-unit',              '~> 3.5'
  gem 'rails-controller-testing'
  # minitest ~> 5.25 required; 6.x breaks the Rails 8 test runner.
  gem 'minitest',               '~> 5.25'
end
