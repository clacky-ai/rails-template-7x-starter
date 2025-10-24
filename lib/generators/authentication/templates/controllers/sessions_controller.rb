class SessionsController < ApplicationController
  before_action :authenticate_user!, only: [:show, :devices, :destroy_one]
  before_action :check_session_cookie_availability, only: [:new]

  def show
    @session = Current.session
    @user = current_user
  end

  def devices
    @sessions = current_user.sessions.order(created_at: :desc)
  end

  def new
    @user = User.new
  end

  def create
    if user = User.authenticate_by(email: params[:user][:email], password: params[:user][:password])
      @session = user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }
      redirect_to root_path, notice: "Signed in successfully"
    else
      redirect_to sign_in_path(email_hint: params[:user][:email]), alert: "That email or password is incorrect"
    end
  end


  def destroy
    @session = Current.session
    @session.destroy!
    cookies.delete(:session_token)
    redirect_to(sign_in_path, notice: "That session has been logged out")
  end

  def destroy_one
    @session = current_user.sessions.find(params[:id])
    @session.destroy!
    redirect_to(devices_session_path, notice: "That session has been logged out")
  end
end
