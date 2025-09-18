class Admin::DashboardController < Admin::BaseController
  # Do not forget to add menu item in app/views/shared/admin/_sidebar.html.erb
  def index
    @admin_count = Administrator.all.size
    @recent_logs = AdminOplog.includes(:administrator).order(created_at: :desc).limit(5)
  end
end
