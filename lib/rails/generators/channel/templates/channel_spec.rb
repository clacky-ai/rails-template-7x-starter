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
    end
  end

  describe "#unsubscribed" do
    it "successfully unsubscribes from the channel" do
      subscribe
      expect(subscription).to be_confirmed

      unsubscribe
      # Channel cleanup is successful if no errors are raised
    end
  end

  # 📨 EXAMPLE: Test send_message action
  # describe "#send_message" do
  #   before { subscribe }
  #
  #   it "handles send_message action" do
  #     expect {
  #       perform :send_message, { content: "Hello world" }
  #     }.not_to raise_error
  #   end
  #
  #   it "broadcasts message" do
  #     expect {
  #       perform :send_message, { content: "Hello world" }
  #     }.to have_broadcasted_to("<%= stream_name %>").with(
  #       hash_including(
  #         type: 'message',
  #         content: 'Hello world'
  #       )
  #     )
  #   end
  # end
end
