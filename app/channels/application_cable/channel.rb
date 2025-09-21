module ApplicationCable
  class Channel < ActionCable::Channel::Base
    rescue_from StandardError, with: :handle_channel_error

    private

    def handle_channel_error(e)
      Rails.logger.error "Channel Error in #{self.class.name}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Send error to client via transmit (direct to this connection)
      transmit({
        type: 'error',
        message: production? ? 'An error occurred' : e.message,
        channel: self.class.name,  # Channel name from backend
        action: action_name,
        success: false,
      })
    end

    def production?
      Rails.env.production?
    end

    def action_name
      @_action_name || 'unknown'
    end

    # Override perform_action to track current action
    def perform_action(data)
      @_action_name = data['action'] || caller_locations(1, 1)[0].label
      super
    end
  end
end
