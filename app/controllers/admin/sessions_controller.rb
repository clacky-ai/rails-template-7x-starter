class Admin::SessionsController < Admin::BaseController
  skip_before_action :authenticate_admin!, only: [:new, :create]
  skip_before_action :check_first_login_password_hint, raise: false

  before_action do
    @full_render = true
  end

  def new
    if first_admin?
      flash.now[:notice] = 'Use admin/admin for the first login to the system'
    end
  end

  def create
    create_first_admin_or_reset_password!
    admin = Administrator.find_by(name: params[:name])
    if admin && admin.authenticate(params[:password])
      admin_sign_in(admin)
      AdminOplogService.log_login(admin, request)
      redirect_to admin_root_path
    else
      flash.now[:alert] = 'Username or password is wrong'
      render 'new'
    end
  end

  def destroy
    AdminOplogService.log_logout(current_admin, request) if current_admin
    admin_sign_out
    redirect_to admin_login_path
  end

  private
  def create_first_admin_or_reset_password!
    return unless first_admin?
    admin = Administrator.find_by(name: 'admin')
    if admin.nil?
      logger.info("System have no admins, create the first one")
      admin = Administrator.new(name: 'admin', password: 'admin', role: 'super_admin')
      admin.save!(validate: false)
    else
      admin.update!(password: 'admin', password_confirmation: 'admin')
    end
  end

  def first_admin?
    return true unless Administrator.first
    admin = Administrator.find_by(name: 'admin')
    return true if admin.nil?
    return true if admin.first_login
  end
end
