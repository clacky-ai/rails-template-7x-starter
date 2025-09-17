class Admin::AdminOplogsController < Admin::BaseController
  before_action :set_admin_oplog, only: [:show]

  def index
    @admin_oplogs = AdminOplog.includes(:administrator)
                              .recent
                              .page(params[:page])
                              .per(20)
    
    # Apply filters
    @admin_oplogs = @admin_oplogs.by_action(params[:action_filter]) if params[:action_filter].present?
    @admin_oplogs = @admin_oplogs.by_administrator(params[:administrator_filter]) if params[:administrator_filter].present?
    
    # For filter dropdowns
    @actions = AdminOplog.distinct.pluck(:action).compact.sort
    @administrators = Administrator.order(:name)
  end

  def show
  end

  private

  def set_admin_oplog
    @admin_oplog = AdminOplog.find(params[:id])
  end
end
