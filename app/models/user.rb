require 'digest/sha1'

class User < ApplicationRecord
  has_secure_password(validations: false)

  alias_method :authenticate_bcrypt, :authenticate

  # Mixins and Plugins
  include Authentication
  include Authentication::ByPassword

  ROLES = %w[redaktion admin alumni].freeze
  STALE_AMBER_YEARS = 3
  STALE_RED_YEARS   = 10

  # Validations
  validates_presence_of     :login
  validates_length_of       :login, :within => 1..40
  validates_uniqueness_of   :login
  validates_format_of       :login, :with => Authentication.login_regex,
                            :message => Authentication.bad_login_message

  validates_presence_of     :email
  validates_length_of       :email, :within => 6..100 #r@a.wk
  validates_uniqueness_of   :email
  validates_format_of       :email, :with => Authentication.email_regex,
                            :message => Authentication.bad_email_message

  validate :roles_are_known
  validate :admin_needs_second_factor

  # Authenticates a user by their login name and unencrypted password. Returns the user or nil.
  def self.authenticate(login, password)
    return if login.blank? || password.blank?

    user = find_by(login: login)
    return unless user

    user&.authenticate(password)
  end

  def authenticate(password)
    if password_digest.present?
      return self if authenticate_bcrypt(password)
      return nil
    end

    return nil unless authenticate_legacy(password)

    transaction do
      self.password = password
      self.crypted_password = nil
      self.salt = nil
      save!(validate: false)
    end

    self
  end

  # TODO: Do we really want to have downcase logins only?
  def login=(value)
    write_attribute :login, (value ? value.downcase : nil)
  end

  def email=(value)
    write_attribute :email, (value ? value.downcase : nil)
  end
  
  def is_admin?
    roles.include?("admin")
  end

  def redaktion?
    roles.include?("redaktion")
  end

  def alumni?
    roles.include?("alumni")
  end

  def role_group
    return :alumni    if alumni?
    return :admin     if is_admin?
    return :redaktion if redaktion?
    :editor
  end

  # Human-readable role names, for the list and the forms.
  def role_labels
    roles.map { |r| I18n.t("users.roles.#{r}", :default => r) }
  end

  def may_change_live?(subject)
    return true unless subject.restricted?
    redaktion?
  end

  def may_change_live_at?(path)
    return true if path.nil?
    return true unless Node.restricted_path?(path)
    redaktion?
  end

  def save_witnessed(actor:)
    saved = false
    transaction do
      saved = save
      raise ActiveRecord::Rollback unless saved
      NodeAction.record!(:participants => [self], :user => actor,
                          :action => "user_create", :target_login => login)
    end
    saved
  end

  def deactivate!(actor:)
    return false if alumni?
    return false if actor == self
    transaction do
      update_column(:roles, (roles | ["alumni"]).sort)
      NodeAction.record!(:participants => [self], :user => actor,
                          :action => "user_deactivate", :target_login => login)
    end
    true
  end

  def reactivate!(actor:)
    return false unless alumni?
    transaction do
      update_column(:roles, (roles - ["alumni"]).sort)
      NodeAction.record!(:participants => [self], :user => actor,
                          :action => "user_reactivate", :target_login => login)
    end
    true
  end

  def grant_redaktion!(actor:)
    return :already if redaktion?
    return :no_second_factor unless otp_enrolled?

    transaction do
      update_column(:roles, (roles | ["redaktion"]).sort)
      NodeAction.record!(:participants => [self], :user => actor,
                          :action => "redaktion_grant", :target_login => login)
    end
    :granted
  end

  def revoke_redaktion!(actor:)
    return :already unless redaktion?
    return :self unless actor != self

    transaction do
      update_column(:roles, (roles - ["redaktion"]).sort)
      NodeAction.record!(:participants => [self], :user => actor,
                          :action => "redaktion_revoke", :target_login => login)
    end
    :revoked
  end

  def grant_admin!(actor:)
    return :already if is_admin?
    return :no_second_factor unless otp_enrolled?

    transaction do
      update_column(:roles, (roles | ["admin"]).sort)
      NodeAction.record!(:participants => [self], :user => actor,
                          :action => "admin_grant", :target_login => login)
    end
    :granted
  end

  def revoke_admin!(actor:)
    return :already unless is_admin?
    return :self unless actor != self

    transaction do
      update_column(:roles, (roles - ["admin"]).sort)
      NodeAction.record!(:participants => [self], :user => actor,
                          :action => "admin_revoke", :target_login => login)
    end
    :revoked
  end

  def update_roles!(desired, actor:)
    desired = Array(desired).map(&:to_s) & ROLES
    refusals = []

    transaction do
      refusals << :admin_not_self         if is_admin?  && !desired.include?("admin")     && actor == self
      refusals << :redaktion_not_self     if redaktion? && !desired.include?("redaktion") && actor == self
      refusals << :cannot_deactivate_self if !alumni?   &&  desired.include?("alumni")    && actor == self
      refusals << :admin_needs_otp        if !is_admin?  && desired.include?("admin")     && !otp_enrolled?
      refusals << :redaktion_needs_otp    if !redaktion? && desired.include?("redaktion") && !otp_enrolled?

      raise ActiveRecord::Rollback if refusals.any?

      revoke_admin!(:actor => actor)     if is_admin?   && !desired.include?("admin")
      revoke_redaktion!(:actor => actor) if redaktion?  && !desired.include?("redaktion")
      reactivate!(:actor => actor)       if alumni?     && !desired.include?("alumni")

      grant_admin!(:actor => actor)     if !is_admin?  && desired.include?("admin")
      grant_redaktion!(:actor => actor) if !redaktion? && desired.include?("redaktion")

      deactivate!(:actor => actor) if !alumni? && desired.include?("alumni")
    end

    refusals
  end

  # otp_secret present == enrolled. otp_pending_secret holds the secret
  # between QR display and first-code confirmation. otp_consumed_timestep
  # makes every accepted code single-use (replay guard within the drift
  # window).

  def otp_enrolled?
    otp_secret.present?
  end

  # Starts (or restarts) enrollment. Returns the provisioning URI the QR
  # encodes; otp_pending_secret itself doubles as the manual-entry string.
  def begin_otp_enrollment!
    update!(:otp_pending_secret => ROTP::Base32.random)
    pending_otp_provisioning_uri
  end

  def pending_otp_provisioning_uri
    return nil if otp_pending_secret.blank?
    ROTP::TOTP.new(otp_pending_secret, :issuer => OTP_ISSUER)
              .provisioning_uri(login)
  end

  # Confirms enrollment with the first generated code. Promotion and
  # witnessing are one transaction; the consumed timestep is recorded so
  # the confirmation code cannot be replayed at login.
  def confirm_otp_enrollment!(code, actor: self)
    return false if otp_pending_secret.blank?
    timestep = ROTP::TOTP.new(otp_pending_secret)
                          .verify(code.to_s.strip,
                                  :drift_behind => OTP_DRIFT,
                                  :drift_ahead  => OTP_DRIFT)
    return false unless timestep

    transaction do
      update!(:otp_secret => otp_pending_secret,
               :otp_pending_secret => nil,
               :otp_consumed_timestep => timestep)
      NodeAction.record!(:participants => [self], :user => actor,
                          :action => "otp_enroll", :target_login => login)
    end
    true
  end

  # Login-time verification. Each code is accepted at most once.
  def verify_otp!(code)
    return false unless otp_enrolled?
    timestep = ROTP::TOTP.new(otp_secret)
                          .verify(code.to_s.strip,
                                  :drift_behind => OTP_DRIFT,
                                  :drift_ahead  => OTP_DRIFT,
                                  :after => otp_consumed_timestep)
    return false unless timestep

    update!(:otp_consumed_timestep => timestep)
    true
  end

  # Self-service disable and administrative reset share one witnessed
  # teardown; the verb records which of the two it was. The controller
  # is responsible for the self-service guards (password + current code).
  def disable_otp!(actor:)
    verb = (actor == self) ? "otp_disable" : "otp_reset"
    transaction do
      update!(:otp_secret => nil, :otp_pending_secret => nil,
               :otp_consumed_timestep => nil)
      NodeAction.record!(:participants => [self], :user => actor,
                          :action => verb, :target_login => login)
    end
    true
  end

  def staleness_tier(now = Time.zone.now)
    return nil if alumni?
    return :never if last_login_at.nil?

    return :red   if last_login_at <= now - STALE_RED_YEARS.years
    return :amber if roles.any? && last_login_at <= now - STALE_AMBER_YEARS.years
    nil
    end
  private

    def roles_are_known
      unknown = roles.to_a - ROLES
      errors.add(:roles, :unknown, :list => unknown.join(", ")) if unknown.any?
    end

    def admin_needs_second_factor
      return unless roles.include?("admin")
      return if otp_secret.present?
      return if persisted? && roles_in_database.to_a.include?("admin")
      errors.add(:roles, :admin_needs_otp)
    end
end
