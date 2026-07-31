require 'digest/sha1'

class User < ApplicationRecord
  has_secure_password(validations: false)

  alias_method :authenticate_bcrypt, :authenticate

  # Mixins and Plugins
  include Authentication
  include Authentication::ByPassword

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
    !!admin
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
end
