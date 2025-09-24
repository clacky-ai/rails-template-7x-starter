class SessionsController < ApplicationController
  before_action :authenticate_user!, only: [:show, :devices, :destroy_one]

  def show
    @session = Current.session
    @user = current_user
  end

  def devices
    @sessions = current_user.sessions.order(created_at: :desc)
  end

  def new
  end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      @session = user.sessions.create!
      
      respond_to do |format|
        format.html do
          cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }
          redirect_to root_path, notice: "Signed in successfully"
        end
        format.json do
          render json: {
            user: {
              id: user.id,
              name: user.name,
              email: user.email
            },
            session_token: @session.id,
            message: "Signed in successfully"
          }, status: :ok
        end
      end
    else
      respond_to do |format|
        format.html do
          redirect_to sign_in_path(email_hint: params[:email]), alert: "That email or password is incorrect"
        end
        format.json do
          render json: {
            error: "That email or password is incorrect"
          }, status: :unauthorized
        end
      end
    end
  end


  def destroy
    respond_to do |format|
      format.html do
        @session = Current.session
        @session.destroy!
        cookies.delete(:session_token)
        redirect_to(sign_in_path, notice: "That session has been logged out")
      end
      format.json do
        @session = Current.session
        @session.destroy!
        render json: { message: "Signed out successfully" }, status: :ok
      end
    end
  end

  def destroy_one
    @session = current_user.sessions.find(params[:id])
    @session.destroy!
    
    respond_to do |format|
      format.html do
        redirect_to(devices_session_path, notice: "That session has been logged out")
      end
      format.json do
        render json: { message: "Session logged out successfully" }, status: :ok
      end
    end
  end
end
