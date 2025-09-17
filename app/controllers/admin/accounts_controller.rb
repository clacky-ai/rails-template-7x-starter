class Admin::AccountsController < Admin::BaseController
  def edit
  end

  def update
    if current_admin.authenticate(params.require(:administrator)[:current_password])
      update_params = admin_params
      # Mark first login as false when password is changed
      update_params[:first_login] = false if update_params[:password].present?
      
      if current_admin.update(update_params)
        admin_sign_out
        redirect_to admin_login_path, notice: 'Account has been updated, please log in again'
      else
        render 'edit'
      end
    else
      flash.now[:alert] = 'Old password is wrong, try again'
      render 'edit'
    end
  end

  private

  def admin_params
    params.require(:administrator).permit(:name, :password, :password_confirmation)
  end
end
