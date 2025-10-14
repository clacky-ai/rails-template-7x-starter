module ApplicationCable
  class Channel < ActionCable::Channel::Base
    rescue_from Exception, with: :handle_channel_error

    # Generate broadcasting name for a given record
    def self.broadcasting_for(record)
      raise ArgumentError, "Record cannot be nil" if record.nil?

      model_name = record.class.name.underscore
      "#{model_name}_#{record.id}"
    end

    private

    def handle_channel_error(e)
      Rails.logger.error "Channel Error in #{self.class.name}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Send error to client via transmit (direct to this connection)
      transmit({
        type: 'system-error',
        message: production? ? 'An error occurred' : e.message,
        channel: self.class.name,  # Channel name from backend
        action: extract_action_from_backtrace(e.backtrace)
      })
    end

    def production?
      Rails.env.production?
    end

    def extract_action_from_backtrace(backtrace)
      # Look through the backtrace to find the channel action method
      backtrace.each do |line|
        # Look for lines that contain our channel files and method names
        if line.include?('app/channels/') && line.include?("in `")
          # Extract method name from backtrace line like:
          # "/path/to/app/channels/alert_channel.rb:15:in `send_alert'"
          method_match = line.match(/in `([^']+)'/)
          if method_match
            method_name = method_match[1]
            # Skip internal methods and return the actual action
            unless method_name.in?(['rescue_from', 'handle_channel_error', 'transmit'])
              return method_name
            end
          end
        end
      end
      'unknown'
    end
  end
end
