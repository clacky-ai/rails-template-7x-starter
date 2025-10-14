class <%= channel_name %> < ApplicationCable::Channel
  def subscribed
    # Stream from a channel based on some identifier
    # Example: stream_from "some_channel"
    stream_from "<%= stream_name %>"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  # 📨 CRITICAL: ALL broadcasts MUST have 'type' field (auto-routes to handleType method)
  #
  # EXAMPLE: Handle send_message action from client
  # def send_message(data)
  #   # Broadcast with type: 'chunk' → client calls handleChunk(data)
  #   ActionCable.server.broadcast(
  #     "<%= stream_name %>",
  #     {
  #       type: 'chunk',  # REQUIRED: routes to handleChunk() method
  #       content: data['content'],
  #       timestamp: Time.current
  #     }
  #   )
  # end

  # EXAMPLE: type with kebab-case auto-converts: 'status-update' → handleStatusUpdate()
  # def update_status(data)
  #   ActionCable.server.broadcast(
  #     "<%= stream_name %>",
  #     {
  #       type: 'status-update',  # Routes to handleStatusUpdate()
  #       status: data['status']
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
