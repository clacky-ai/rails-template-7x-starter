module FriendlyErrorHandlingConcern
  extend ActiveSupport::Concern

  included do
    # Only handle errors in development environment, test environment should raise error
    if Rails.env.development?
      rescue_from NameError, with: :handle_friendly_error
      rescue_from StandardError, with: :handle_friendly_error
      rescue_from ActionView::SyntaxErrorInTemplate, with: :handle_friendly_error
      rescue_from ActiveRecord::StatementInvalid, with: :handle_friendly_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_friendly_error
      rescue_from ActionController::MissingExactTemplate, with: :render_missing_template_fallback

      before_action :check_pending_migrations
    end
  end

  def handle_routing_error
    Rails.logger.error("404 - Path not found: #{request.path}")
    @error_url = request.path
    @error_title = "Page Not Found"
    @error_description = "The page you're looking for doesn't exist. Please check the URL or go back to the homepage."
    render "shared/friendly_error", status: :not_found
  end

  private

  def check_pending_migrations
    ActiveRecord::Migration.check_all_pending!
  end

  def render_missing_template_fallback(exception)
    if request.format.html?
      Rails.logger.info("Missing template: #{exception}. Fallback rendering.")
      render "shared/missing_template_fallback", status: :ok
    else
      raise exception
    end
  end

  def handle_migration_error(exception)
    Rails.logger.error("Migration Error: #{exception.class.name}")
    Rails.logger.error("Message: #{exception.message}")
    Rails.logger.error(filter_user_backtrace(exception.backtrace).join("\n"))

    if request.format.html?
      @error_url = request.path
      @original_exception = exception
      @filtered_backtrace = filter_user_backtrace(exception.backtrace)
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
    # Skip friendly error handling for curl requests - let them see raw errors for debugging
    if curl_request?
      raise exception
    end

    if exception.is_a?(ActiveRecord::PendingMigrationError)
      handle_migration_error(exception)
      return
    end

    Rails.logger.error("Application Error: #{exception.class.name}")
    Rails.logger.error("Message: #{exception.message}")
    Rails.logger.error(filter_user_backtrace(exception.backtrace).join("\n"))

    if request.format.html?
      @error_url = request.path
      @original_exception = exception
      @filtered_backtrace = filter_user_backtrace(exception.backtrace)
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

  # Check if the request is from curl
  def curl_request?
    user_agent = request.headers['User-Agent'].to_s.downcase
    user_agent.include?('curl') || 
    user_agent.include?('httpie') ||
    user_agent.include?('wget')
  end

  # Filter backtrace to show only user code, excluding framework and gem traces
  def filter_user_backtrace(backtrace)
    return [] unless backtrace

    # Use Rails built-in backtrace cleaner to filter framework/gem traces
    cleaned_backtrace = Rails.backtrace_cleaner.clean(backtrace)

    # Further filter out internal concern methods
    filtered_backtrace = cleaned_backtrace.reject do |line|
      line.include?('check_pending_migrations') ||
      line.include?('friendly_error_handling_concern.rb')
    end

    # If filtered backtrace is empty, fall back to cleaned backtrace, then original
    if filtered_backtrace.empty?
      cleaned_backtrace.empty? ? backtrace.first(3) : cleaned_backtrace.first(10)
    else
      filtered_backtrace.first(10)
    end
  end
end
