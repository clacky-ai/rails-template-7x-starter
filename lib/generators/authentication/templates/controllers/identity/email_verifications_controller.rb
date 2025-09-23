class Identity::EmailVerificationsController < ApplicationController
  before_action :authenticate_user!, only: :create

  before_action :set_user, only: :show

  def show
    @user.update! verified: true
    redirect_to root_path, notice: "Thank you for verifying your email address"
  end

  def create
    if @user.email_was_generated?
      Rails.logger.info("Email was generated for user #{@user.id}, will skip email verification")
      redirect_to edit_identity_email_path, alert: "Your email was generated, you need to update it"
    end
    send_email_verification
    redirect_to root_path, notice: "We sent a verification email to your email address"
  end

  private

  def set_user
    @user = User.find_by_token_for!(:email_verification, params[:sid])
  rescue StandardError
    redirect_to edit_identity_email_path, alert: "That email verification link is invalid"
  end

  def send_email_verification
    UserMailer.with(user: Current.user).email_verification.deliver_later
  end
end
