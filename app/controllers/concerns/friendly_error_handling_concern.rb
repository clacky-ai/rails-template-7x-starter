module FriendlyErrorHandlingConcern
  extend ActiveSupport::Concern

  included do
    if Rails.env.development?
      rescue_from ActionView::SyntaxErrorInTemplate, with: :handle_friendly_error
      rescue_from ActiveRecord::StatementInvalid, with: :handle_friendly_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_friendly_error
      rescue_from StandardError, with: :handle_friendly_error

      before_action :check_pending_migrations
    end
  end

  private

  def check_pending_migrations
    ActiveRecord::Migration.check_all_pending!
  end

  def handle_routing_error
    Rails.logger.error("404 - Path not found: #{request.path}")
    @error_url = request.path
    @error_title = "Page Not Found"
    @error_description = "The page you're looking for doesn't exist. Please check the URL or go back to the homepage."
    render "shared/friendly_error", status: :not_found
  end

  def handle_migration_error(exception)
    Rails.logger.error("Migration Error: #{exception.class.name}")
    Rails.logger.error("Message: #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))

    if request.format.html?
      @error_url = request.path
      @original_exception = exception if Rails.env.development?
      @error_title = "System Under Development"
      @error_description = "The system needs to be updated. Please refresh the page or try again later."
      render "shared/friendly_error", status: :service_unavailable
    else
      render json: {
        error: 'Database migration required',
        message: Rails.env.development? ? exception.message : 'System maintenance in progress',
        code: 'PENDING_MIGRATION_ERROR'
      }, status: :service_unavailable
    end
  end

  def handle_friendly_error(exception)
    if exception.is_a?(ActiveRecord::PendingMigrationError)
      handle_migration_error(exception)
      return
    end

    Rails.logger.error("Application Error: #{exception.class.name}")
    Rails.logger.error("Message: #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))

    if request.format.html?
      @error_url = request.path
      @original_exception = exception if Rails.env.development?
      @error_title = "Something Went Wrong"
      @error_description = "Please copy error details and send it to chatbox"
      render "shared/friendly_error", status: :internal_server_error
    else
      render json: {
        error: 'An error occurred',
        message: Rails.env.development? ? exception.message : 'Please try again later'
      }, status: :internal_server_error
    end
  end
end
