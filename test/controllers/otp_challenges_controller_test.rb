require "test_helper"

class OtpChallengesControllerTest < ActionController::TestCase
  fixtures :users

  def setup
    @user = users(:quentin)
    @user.update!(:otp_secret => ROTP::Base32.random)
    @request.session[:pending_otp_user_id] = @user.id
    @request.session[:otp_deadline]        = 2.minutes.from_now.to_i
    @request.session[:otp_attempts]        = 0
  end

  test "a valid code completes the login" do
    post :create, params: { :code => ROTP::TOTP.new(@user.otp_secret).now }
    assert_equal @user.id, session[:user_id]
    assert_nil session[:pending_otp_user_id]
  end

  test "a wrong code does not log in" do
    post :create, params: { :code => "000000" }
    assert_nil session[:user_id]
    assert_response :success
  end

  test "the pending window expires" do
    @request.session[:otp_deadline] = 1.minute.ago.to_i
    post :create, params: { :code => ROTP::TOTP.new(@user.otp_secret).now }
    assert_nil session[:user_id]
    assert_redirected_to login_path
  end

  test "attempts are limited" do
    5.times { post :create, params: { :code => "000000" } }
    post :create, params: { :code => ROTP::TOTP.new(@user.otp_secret).now }
    assert_nil session[:user_id]
    assert_redirected_to login_path
  end
end
