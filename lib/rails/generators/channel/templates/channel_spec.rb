require 'rails_helper'

RSpec.describe <%= channel_name %>, type: :channel do
<% if requires_authentication? -%>
  # Channel requires authentication (--auth flag was used)
  # If you need to test without authentication, remove --auth flag when generating
  let(:user) { create(:user) }

  before do
    # Stub the connection's current_user method
    stub_connection current_user: user
  end
<% else -%>
  # Channel does not require authentication
  # If you need user authentication, add --auth flag when generating the channel
  # Uncomment the following lines if you want to test with authenticated users:
  #
  # let(:user) { create(:user) }
  #
  # before do
  #   stub_connection current_user: user
  # end
<% end -%>

  describe "#subscribed" do
    it "successfully subscribes to the channel" do
      subscribe

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("<%= stream_name %>")
    end
  end

  describe "#unsubscribed" do
    it "successfully unsubscribes from the channel" do
      subscribe
      unsubscribe_from_channel

      expect(subscription).not_to be_confirmed
    end
  end

<% actions.each do |action| %>
  describe "#<%= action %>" do
    before { subscribe }

    it "handles <%= action %> action" do
      expect {
        perform :<%= action %>, { message: "test data" }
      }.not_to raise_error
    end

    it "broadcasts <%= action %> message" do
      expect {
        perform :<%= action %>, { message: "test data" }
      }.to have_broadcasted_to("<%= stream_name %>")
    end
  end

<% end %>
end
