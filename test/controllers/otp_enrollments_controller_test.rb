require "test_helper"

class OtpEnrollmentsControllerTest < ActionController::TestCase
  include AuthenticatedTestHelper
  fixtures :users

  def setup
    login_as :quentin
    @user = users(:quentin)
    User.authenticate("quentin", "monkey") # ensure digest is migrated
  end

  test "create requires the current password" do
    post :create, params: { :current_password => "wrong" }
    assert_nil @user.reload.otp_pending_secret
  end

  test "create with the password begins enrollment" do
    post :create, params: { :current_password => "monkey" }
    assert @user.reload.otp_pending_secret.present?
    assert_redirected_to otp_enrollment_path
  end

  test "update with the first code completes enrollment" do
    @user.begin_otp_enrollment!
    code = ROTP::TOTP.new(@user.reload.otp_pending_secret).now
    put :update, params: { :code => code }
    assert @user.reload.otp_enrolled?
  end

  test "destroy needs password and a current code" do
    @user.update!(:otp_secret => ROTP::Base32.random)

    delete :destroy, params: { :current_password => "monkey", :code => "000000" }
    assert @user.reload.otp_enrolled?

    code = ROTP::TOTP.new(@user.otp_secret).now
    delete :destroy, params: { :current_password => "monkey", :code => code }
    assert_not @user.reload.otp_enrolled?
  end
end
