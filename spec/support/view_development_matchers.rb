# spec/support/view_development_matchers.rb
module ViewDevelopmentMatchers
  extend RSpec::Matchers::DSL

  matcher :be_success_with_view_check do |action_name = nil|
    match do |response|
      case response.status
      when 200, 201, 202, 204
        true
      when 406
        action_info = action_name ? "##{action_name}" : ""
        controller_name = response.request.params[:controller]
        @view_not_developed_message = "Views for #{controller_name}#{action_info} are not yet developed"
        false
      else
        false
      end
    end

    failure_message do |response|
      if response.status == 406 && @view_not_developed_message
        @view_not_developed_message
      else
        "expected response to be successful, but got #{response.status}"
      end
    end

    failure_message_when_negated do |response|
      "expected response not to be successful, but got #{response.status}"
    end

    description do
      "be successful (with helpful message if views not developed)"
    end
  end
end

RSpec.configure do |config|
  config.include ViewDevelopmentMatchers, type: :request
end
