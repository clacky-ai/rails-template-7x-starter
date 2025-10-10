class PasswordsController < ApplicationController
  before_action :authenticate_user!
  def edit
  end

  def update
    if current_user.update(user_params)
      redirect_to root_path, notice: "Your password has been changed"
    else
      flash.now[:alert] = handle_password_errors(current_user)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:password, :password_confirmation, :password_challenge).with_defaults(password_challenge: "")
  end
end
