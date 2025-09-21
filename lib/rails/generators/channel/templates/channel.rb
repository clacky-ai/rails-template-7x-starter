class <%= channel_name %> < ApplicationCable::Channel
  def subscribed
    # Stream from a channel based on some identifier
    # Example: stream_from "some_channel"
    stream_from "<%= stream_name %>"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

<% actions.each do |action| %>
  def <%= action %>(data)
    # Handle <%= action %> action
    # You can access:
    # - data: the data sent from client
    # - current_user: the authenticated user (if available)
    # - params: parameters passed when subscribing
    
    # Example broadcast:
    # ActionCable.server.broadcast(
    #   "<%= stream_name %>",
    #   {
    #     type: '<%= action %>',
    #     data: data,
    #     user: current_user&.slice(:id, :name, :email)
    #   }
    # )
  end

<% end %>
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
