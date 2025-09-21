import consumer from "./consumer"

// Channel factory function - call this to create a connection when needed
function create<%= channel_name.gsub('Channel', '') %>Channel(params = {}) {
  return consumer.subscriptions.create(
    {
      channel: "<%= channel_name %>",
      ...params<% if actions.include?('subscribed') %>,
      // Add any parameters needed for subscription
      // room_id: document.querySelector('[data-room-id]')?.dataset.roomId<% end %>
    },
    {
    connected() {
      // Called when the subscription is ready for use on the server
      console.log("Connected to <%= channel_name %>");
    },

    disconnected() {
      // Called when the subscription has been terminated by the server
      console.log("Disconnected from <%= channel_name %>");
    },

    received(data) {
      // Called when there's incoming data on the websocket for this channel
      console.log("Received data:", data);

      // Global error handling
      if (data.type === 'error' && data.success === false) {
        this.handleGlobalError(data);
        return;
      }

      // Handle different types of messages
      switch(data.type) {
<% actions.each do |action| %>
        case '<%= action %>':
          this.handle<%= action.camelize %>(data);
          break;
<% end %>
        default:
          console.log("Unknown message type:", data.type);
      }
    },

    // Global error handling for this channel
    handleGlobalError(errorData) {
      // Send to global error handler
      if (window.errorHandler && window.errorHandler.handleActionCableError) {
        window.errorHandler.handleActionCableError({
          ...errorData,
        });
      } else {
        // Fallback error handling
        console.error('Channel Error:', {
          ...errorData
        });
      }
    },

<% actions.each do |action| %>
    // Send <%= action %> to the server
    <%= action.camelize(:lower) %>(data) {
      this.perform('<%= action %>', data);
    },

    // Handle <%= action %> message from server
    handle<%= action.camelize %>(data) {
      // Implement your <%= action %> handling logic here
      console.log('<%= action.camelize %> received:', data);
    },

<% end %>
    }
  );
}

// Make factory function available globally for easy access in views
window.create<%= channel_name.gsub('Channel', '') %>Channel = create<%= channel_name.gsub('Channel', '') %>Channel;

// Export the factory function
export default create<%= channel_name.gsub('Channel', '') %>Channel;

// Optional: Create a default instance (uncomment if you want auto-connection)
// const <%= javascript_channel_name %>Channel = create<%= channel_name.gsub('Channel', '') %>Channel();
// window.<%= javascript_channel_name %>Channel = <%= javascript_channel_name %>Channel;
// export default <%= javascript_channel_name %>Channel;