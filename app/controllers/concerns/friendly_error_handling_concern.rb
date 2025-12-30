module FriendlyErrorHandlingConcern
  extend ActiveSupport::Concern

  included do
    # Force JSON format for API requests
    before_action :set_default_format_for_api

    # Global error handling for both API and HTML controllers
    if Rails.env.development?
      rescue_from StandardError, with: :handle_friendly_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found_error
      rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing_error

      # Additional rescues for development HTML
      rescue_from NameError, with: :handle_friendly_error
      rescue_from ActionView::SyntaxErrorInTemplate, with: :handle_friendly_error
      rescue_from ActiveRecord::StatementInvalid, with: :handle_friendly_error
      rescue_from ActionController::MissingExactTemplate, with: :render_missing_template_fallback

      before_action :check_pending_migrations
    end
  end

  def handle_routing_error(path = nil)
    Rails.logger.error("404 - Path not found: #{request.method} #{request.path}", broadcast: false)

    if request.format.json?
      render json: {
        error: 'Not found',
        message: 'The requested endpoint does not exist'
      }, status: :not_found
    else
      @http_method = request.method
      @error_url = request.path
      @error_title = "Page Not Found"
      @error_description = "If you confirm this is missing implementation, please copy error details and send to chatbox."
      render "shared/friendly_error", status: :not_found
    end
  end

  private

  # Force JSON format for API requests
  def set_default_format_for_api
    request.format = :json if request.path.start_with?('/api/')
  end

  # Handle 404 Not Found errors (from ActiveRecord)
  def handle_not_found_error(exception)
    Rails.logger.error("Record not found: #{exception.message}", broadcast: false)

    if request.format.json?
      render json: {
        error: 'Resource not found',
        message: exception.message
      }, status: :not_found
    elsif Rails.env.development?
      @http_method = request.method
      @error_url = request.path
      @original_exception = exception
      @filtered_backtrace = filter_user_backtrace(exception.backtrace)
      @error_title = "Record Not Found"
      @error_description = exception.message
      render "shared/friendly_error", status: :not_found
    else
      raise exception
    end
  end

  # Handle validation errors (422 Unprocessable Entity)
  def handle_validation_error(exception)
    Rails.logger.error("Validation failed: #{exception.record.errors.full_messages.join(', ')}", broadcast: false)

    if request.format.json?
      render json: {
        error: 'Validation failed',
        errors: exception.record.errors.full_messages
      }, status: :unprocessable_entity
    elsif Rails.env.development?
      @http_method = request.method
      @error_url = request.path
      @original_exception = exception
      @filtered_backtrace = filter_user_backtrace(exception.backtrace)
      @error_title = "Validation Error"
      @error_description = exception.record.errors.full_messages.join(', ')
      render "shared/friendly_error", status: :unprocessable_entity
    else
      raise exception
    end
  end

  # Handle missing parameters (400 Bad Request)
  def handle_parameter_missing_error(exception)
    Rails.logger.error("Parameter missing: #{exception.message}", broadcast: false)

    if request.format.json?
      render json: {
        error: 'Parameter missing',
        message: exception.message
      }, status: :bad_request
    elsif Rails.env.development?
      @http_method = request.method
      @error_url = request.path
      @original_exception = exception
      @filtered_backtrace = filter_user_backtrace(exception.backtrace)
      @error_title = "Parameter Missing"
      @error_description = exception.message
      render "shared/friendly_error", status: :bad_request
    else
      raise exception
    end
  end

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
    Rails.logger.error("Migration Error: #{exception.class.name}", broadcast: false)
    Rails.logger.error("Message: #{exception.message}", broadcast: false)
    Rails.logger.error(filter_user_backtrace(exception.backtrace).join("\n"), broadcast: false)

    if request.format.html?
      @http_method = request.method
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
    if curl_request? && !request.format.json?
      raise exception
    end

    if exception.is_a?(ActiveRecord::PendingMigrationError)
      handle_migration_error(exception)
      return
    end

    Rails.logger.error("Application Error: #{exception.class.name}", broadcast: false)
    Rails.logger.error("Message: #{exception.message}", broadcast: false)
    Rails.logger.error(filter_user_backtrace(exception.backtrace).join("\n"), broadcast: false)

    if request.format.json?
      # JSON/API responses
      if Rails.env.production?
        render json: {
          error: 'Internal server error',
          message: 'An unexpected error occurred'
        }, status: :internal_server_error
      else
        render json: {
          error: exception.class.name,
          message: exception.message,
          backtrace: filter_user_backtrace(exception.backtrace)
        }, status: :internal_server_error
      end
    else
      # HTML responses - friendly error page (for html and unknown formats)
      @http_method = request.method
      @error_url = request.path
      @original_exception = exception
      @filtered_backtrace = filter_user_backtrace(exception.backtrace)
      @error_title = "Something Went Wrong"
      @error_description = "Please copy error details and send it to chatbox"
      render "shared/friendly_error", status: :internal_server_error, formats: [:html]
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
      line.include?('friendly_error_handling_concern.rb') ||
      line.include?('clacky_health_check')
    end

    # If filtered backtrace is empty, fall back to cleaned backtrace, then original
    if filtered_backtrace.empty?
      cleaned_backtrace.empty? ? backtrace.first(3) : cleaned_backtrace.first(10)
    else
      filtered_backtrace.first(10)
    end
  end
end
