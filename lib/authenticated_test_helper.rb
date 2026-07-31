module AuthenticatedTestHelper
  # Sets the current user in the session from the user fixtures.
  def login_as(user)
    @request.session[:user_id] = user ? users(user).id : nil
    @request.session[:logged_in_at] = Time.now.to_i
  end

  def elevate_session!
    session[:elevated_at] = Time.now.to_i
  end
end
