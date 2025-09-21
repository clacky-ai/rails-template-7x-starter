import consumer from "channels/consumer"

const <%= javascript_channel_name %>Channel = consumer.subscriptions.create(
  {
    channel: "<%= channel_name %>"<% if actions.include?('subscribed') %>,
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

      // Handle different types of messages
      switch(data.type) {
<% actions.each do |action| %>
        case '<%= action %>':
          this.handle<%= action.capitalize %>(data);
          break;
<% end %>
        default:
          console.log("Unknown message type:", data.type);
      }
    },

<% actions.each do |action| %>
    // Send <%= action %> to the server
    <%= action %>(data) {
      this.perform('<%= action %>', data);
    },

    // Handle <%= action %> message from server
    handle<%= action.capitalize %>(data) {
      // Implement your <%= action %> handling logic here
      console.log('<%= action.capitalize %> received:', data);
    },

<% end %>
    // Example method to send data to the server
    send(data) {
      this.perform('receive', data);
    }
  }
);

export default <%= javascript_channel_name %>Channel;
