# After creating a new admin controller, Do not forget to add menu item in shared/admin/_sidebar.html.erb
class Admin::BaseController < ActionController::Base
  layout 'admin'

  include FriendlyErrorHandlingConcern

  protect_from_forgery with: :exception

  before_action :authenticate_admin!
  before_action :check_first_login_password_hint
  around_action :log_admin_action

  helper_method :current_admin

  private

  def authenticate_admin!
    if current_admin.blank?
      redirect_to admin_login_path
      return
    end

    if current_admin.password_digest != session[:current_admin_token]
      redirect_to admin_login_path, alert: 'Password was changed, please log in again'
      return
    end
  end

  def current_admin
    @_current_admin ||= session[:current_admin_id] && Administrator.find_by(id: session[:current_admin_id])
  end

  def admin_sign_in(admin)
    session[:current_admin_id] = admin.id
    session[:current_admin_token] = admin.password_digest
  end

  def admin_sign_out
    session[:current_admin_id] = nil
    session[:current_admin_token] = nil
    @_current_admin = nil
  end

  def check_first_login_password_hint
    return unless current_admin
    return unless current_admin.first_login?
    return if controller_name == 'accounts' && action_name == 'edit'
    return if controller_name == 'accounts' && action_name == 'update'

    flash.now[:warning] = "Welcome! For security reasons, we recommend changing your default password. #{ActionController::Base.helpers.link_to('Change Password', edit_admin_account_path, class: 'underline')}".html_safe
  end

  def log_admin_action
    # Skip logging for certain actions
    return yield if skip_logging?

    # Store the resource before action (for updates/deletes)
    @_oplog_resource = find_resource_for_logging

    yield

    # Log the action after successful completion
    log_action_to_oplog
  rescue StandardError => e
    # Still log the action even if it failed
    log_action_to_oplog(error: e.message)
    raise
  end

  def skip_logging?
    # Skip logging for certain controllers/actions
    return true if controller_name == 'sessions' # Sessions have their own logging
    return true if action_name.in?(%w[new edit show index]) # Read-only actions
    false
  end

  def find_resource_for_logging
    # Try to find the resource being operated on
    return nil unless params[:id]

    # Determine the model class from controller name
    model_name = controller_name.classify
    return nil unless Object.const_defined?(model_name)

    model_class = model_name.constantize
    model_class.find_by(id: params[:id])
  rescue
    nil
  end

  def log_action_to_oplog(error: nil)
    return unless current_admin

    details = {}
    details[:error] = error if error
    details[:params] = filtered_params if action_name.in?(%w[create update])

    AdminOplogService.log_action(
      current_admin,
      action_name,
      request,
      resource: @_oplog_resource,
      details: details
    )
  end

  def filtered_params
    # Remove sensitive parameters
    request.parameters.except('controller', 'action', 'authenticity_token', 'password', 'password_confirmation')
  end
end
