module AuthenticatedTestHelper
  # Sets the current user in the session from the user fixtures.
  def login_as(user)
    @request.session[:user_id] = user ? users(user).id : nil
    @request.session[:logged_in_at] = Time.now.to_i
  end

  def elevate_session!
    user = User.find_by(:id => @request.session[:user_id])
    if user && !user.otp_enrolled?
      user.update_column(:otp_secret, ROTP::Base32.random)
    end
    @request.session[:elevated_at] = Time.now.to_i
  end
end
