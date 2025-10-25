class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  discard_on ActiveJob::DeserializationError

  # ⚠️  CRITICAL: DO NOT use `rescue` in subclass Jobs!
  # All exceptions are automatically caught here and reported to the frontend.
  # If you catch exceptions in your Job, they will be "swallowed" and not reported.
  # Let exceptions bubble up to this global handler.

  # Capture all job errors and broadcast to frontend via Turbo Streams
  rescue_from StandardError do |exception|
    # Broadcast error to frontend via GlobalErrorsChannel
    broadcast_job_error(exception)

    # Re-raise to allow normal error handling (retry, logging, etc.)
    raise exception
  end

  private

  def broadcast_job_error(exception)
    # Filter backtrace to show only user code
    filtered_backtrace = Rails.backtrace_cleaner.clean(exception.backtrace || [])
    user_backtrace = filtered_backtrace.empty? ? exception.backtrace&.first(10) : filtered_backtrace.first(10)

    error_data = {
      message: "#{exception.class}: #{exception.message}",
      job_class: self.class.name,
      job_id: job_id,
      queue: queue_name,
      exception_class: exception.class.name,
      backtrace: user_backtrace&.join("\n")
    }

    # Broadcast inline turbo-stream without template
    Turbo::StreamsChannel.broadcast_render_to(
      "system_monitor",
      inline: "<turbo-stream action='report_async_error' data-error='<%= error_data.to_json.gsub(\"'\", \"&#39;\") %>'></turbo-stream>",
      locals: { error_data: error_data }
    )
  rescue => broadcast_error
    # Silently fail if broadcast fails (don't disrupt job error handling)
    Rails.logger.error("Failed to broadcast job error: #{broadcast_error.message}")
  end
end
