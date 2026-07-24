if ENV["PSEUDO_I18N"]
  module PseudoI18nDecoration
    def translate(locale, key, options = {})
      result = super
      return result unless result.is_a?(String)
      ENV["PSEUDO_I18N"] == "redact" ? "▚" * result.length : "⟦#{result}⟧"
    end
  end
  I18n.backend.class.prepend(PseudoI18nDecoration)
end
