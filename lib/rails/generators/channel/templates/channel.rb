class <%= channel_name %> < ApplicationCable::Channel
  def subscribed
    # Stream from a channel based on some identifier
    # Example: stream_from "some_channel"
    stream_from "<%= stream_name %>"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  # 📨 EXAMPLE: Handle send_message action from client
  # def send_message(data)
  #   # TODO: Save message to database, validate, etc.
  #   # You can access:
  #   # - data: the data sent from client
  #   # - current_user: the authenticated user (if available)
  #   # - params: parameters passed when subscribing
  #
  #   # Broadcast to all subscribers
  #   ActionCable.server.broadcast(
  #     "<%= stream_name %>",
  #     {
  #       type: 'message',
  #       content: data['content'],
  #       user: current_user&.slice(:id, :name, :email),
  #       timestamp: Time.current
  #     }
  #   )
  # end

  # 📊 EXAMPLE: Handle update_status action from client
  # def update_status(data)
  #   # TODO: Update user status, validate, etc.
  #
  #   # Broadcast status update to subscribers
  #   ActionCable.server.broadcast(
  #     "<%= stream_name %>",
  #     {
  #       type: 'status_update',
  #       status: data['status'],
  #       user: current_user&.slice(:id, :name, :email),
  #       timestamp: Time.current
  #     }
  #   )
  # end
  private

<% if requires_authentication? -%>
  def current_user
    @current_user ||= connection.current_user
  end
<% else -%>
  # def current_user
  #   @current_user ||= connection.current_user
  # end
<% end -%>
end
