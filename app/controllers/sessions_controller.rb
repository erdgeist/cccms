# This controller handles the login/logout function of the site.  
class SessionsController < ApplicationController
  
  # Public
  
  layout 'admin'
  
  # render new.rhtml
  def new
  end

  def create
    logout_keeping_session!
    user = User.authenticate(params[:login], params[:password])
    if user
      return_to = session[:return_to]

      # Protects against session fixation attacks, causes request forgery
      # protection if user resubmits an earlier form using back
      # button. Uncomment if you understand the tradeoffs.
      reset_session
      
      if user.otp_enrolled?
        # Half-completed login: no user_id yet, only the pending marker.
        session[:pending_otp_user_id] = user.id
        session[:otp_deadline]        = 2.minutes.from_now.to_i
        session[:otp_attempts]        = 0
        session[:return_to]           = return_to
        redirect_to new_otp_challenge_path
      else
        self.current_user = user
        session[:logged_in_at] = Time.now.to_i

        if user.otp_required?
          flash[:error] = t("flash.sessions.otp_setup_now")
          redirect_to edit_user_path(user)
        else
          flash[:notice] = t("flash.common.logged_in")
          redirect_to safe_return_to(return_to, :default => admin_path)
        end
      end
    else
      note_failed_signin
      @login = params[:login]
      render :action => 'new'
    end
  end

  def destroy
    logout_killing_session!
    flash[:notice] = t("flash.sessions.logged_out")
    redirect_back_or_default('/login')
  end

protected
  # Track failed login attempts
  def note_failed_signin
    flash[:error] = t("flash.sessions.failed")
    logger.warn "Failed login for '#{params[:login]}'" \
                "from #{request.remote_ip} at #{Time.now.utc}"
  end
end
