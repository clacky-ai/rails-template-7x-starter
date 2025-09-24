class Sessions::OmniauthController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def create
    @user = User.from_omniauth(omniauth)

    if @user.persisted?
      session_record = @user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

      redirect_to root_path, notice: "Successfully signed in with #{omniauth.provider.humanize}"
    else
      flash[:alert] = handle_password_errors(@user)
      redirect_to sign_in_path
    end
  end

  def failure
    flash[:alert] = "Authentication failed: #{params[:message]&.humanize || 'Unknown error'}"
    redirect_to sign_in_path
  end

  private

  def omniauth
    request.env["omniauth.auth"]
  end
end
