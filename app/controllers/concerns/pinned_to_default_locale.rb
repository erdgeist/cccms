# Chrome locale and content locale are separate concerns, and in the
# admin they must not touch. Globalize.locale falls back to
# I18n.locale when unset, so without this pin a visit to /en/admin
# would silently switch every Page and MenuItem read to its English
# translation.
#
# Translation editors are the exception and select their locale from
# params, not from the chrome. They nest their own
# Globalize.with_locale inside this one, which wins.
module PinnedToDefaultLocale
  extend ActiveSupport::Concern

  included do
    around_action :pin_to_default_locale
  end

  private

    def pin_to_default_locale
      Globalize.with_locale(I18n.default_locale) { yield }
    end
end
