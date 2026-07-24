require "test_helper"

class UserOtpTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    @user = users(:quentin)
  end

  test "begin_otp_enrollment! stores a pending secret and yields a provisioning URI" do
    uri = @user.begin_otp_enrollment!
    assert @user.otp_pending_secret.present?
    assert_not @user.otp_enrolled?
    assert_match %r{\Aotpauth://totp/}, uri
    assert_includes uri, "issuer="
  end

  test "confirm_otp_enrollment! promotes the pending secret and witnesses it" do
    @user.begin_otp_enrollment!
    code = ROTP::TOTP.new(@user.otp_pending_secret).now

    assert @user.confirm_otp_enrollment!(code)
    assert @user.otp_enrolled?
    assert_nil @user.otp_pending_secret

    action = NodeAction.where(:action => "otp_enroll").last
    assert_equal @user, action.user
    assert_equal [["User", @user.id]],
                 action.action_participants.map { |p| [p.subject_type, p.subject_id] }
  end

  test "confirm_otp_enrollment! rejects a wrong code and stays unenrolled" do
    @user.begin_otp_enrollment!
    assert_not @user.confirm_otp_enrollment!("000000")
    assert_not @user.otp_enrolled?
    assert @user.otp_pending_secret.present?
  end

  test "verify_otp! accepts a current code exactly once" do
    @user.update!(:otp_secret => ROTP::Base32.random)
    code = ROTP::TOTP.new(@user.otp_secret).now

    assert @user.verify_otp!(code)
    assert_not @user.verify_otp!(code), "replayed code must be rejected"
  end

  test "the confirmation code cannot be replayed at login" do
    @user.begin_otp_enrollment!
    code = ROTP::TOTP.new(@user.otp_pending_secret).now
    @user.confirm_otp_enrollment!(code)
    assert_not @user.verify_otp!(code)
  end

  test "verify_otp! rejects wrong codes and unenrolled users" do
    assert_not @user.verify_otp!("123456")
    enroll!(@user)
    assert_not @user.verify_otp!("000000")
  end

  test "disable_otp! by the user themselves is witnessed as otp_disable" do
    enroll!(@user)
    assert @user.disable_otp!(:actor => @user)
    assert_not @user.otp_enrolled?
    assert_equal "otp_disable", NodeAction.last.action
  end

  test "an admin clearing another user's factor is witnessed as otp_reset" do
    enroll!(@user)
    admin = users(:aaron)
    assert @user.disable_otp!(:actor => admin)

    action = NodeAction.where(:action => "otp_reset").last
    assert_equal admin, action.user
    assert_equal @user.login, action.metadata["target_login"]
  end

  private

    def enroll!(user)
      user.begin_otp_enrollment!
      user.confirm_otp_enrollment!(ROTP::TOTP.new(user.otp_pending_secret).now)
    end
end
