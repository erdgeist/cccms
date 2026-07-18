# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src    :self
    policy.script_src     :self
    policy.style_src      :self, :unsafe_inline
    policy.img_src        :self, :data
    policy.font_src       :self
    policy.object_src     :none
    policy.frame_ancestors :none
    policy.base_uri       :self
    policy.form_action    :self
    policy.report_uri     "/csp_reports"
  end

  # Per-request nonce; script-src only. style-src keeps unsafe_inline
  # deliberately: TinyMCE emits img[style] in body content and the
  # public layout carries style attributes -- CSS injection is a
  # low-yield channel, script-src is where the protection lives.
  config.content_security_policy_nonce_generator  = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Report-only: nothing blocks. Enforcement is a later, deliberate
  # flip once the reports have mapped reality (admin inline scripts,
  # legacy hotlinked images in old bodies, embeds).
  config.content_security_policy_report_only = true
end
