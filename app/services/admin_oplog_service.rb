class AdminOplogService < ApplicationService
  def initialize(administrator:, action:, request:, resource: nil, details: nil)
    @administrator = administrator
    @action = action
    @request = request
    @resource = resource
    @details = details
  end

  def call
    create_oplog
  end

  private

  attr_reader :administrator, :action, :request, :resource, :details

  def create_oplog
    AdminOplog.create!(
      administrator: administrator,
      action: action,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      ip_address: request_ip,
      user_agent: request&.user_agent,
      details: build_details
    )
  rescue StandardError => e
    # Log the error but don't let it affect the main operation
    Rails.logger.error "Failed to create admin oplog: #{e.message}"
    nil
  end

  def request_ip
    return 'Unknown' unless request

    # Try to get the real IP address from various headers
    request.env['HTTP_X_REAL_IP'] ||
    request.env['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip ||
    request.remote_ip ||
    'Unknown'
  end

  def build_details
    detail_hash = {}
    
    # Add custom details if provided
    detail_hash.merge!(details) if details.is_a?(Hash)
    
    # Add resource information
    if resource
      detail_hash[:resource_name] = resource_name
      detail_hash[:resource_attributes] = resource_attributes if action.in?(['create', 'update'])
    end
    
    # Add request information
    detail_hash[:controller] = request&.controller_class&.name
    detail_hash[:action_name] = request&.params&.dig('action')
    detail_hash[:method] = request&.method
    
    detail_hash.to_json
  end

  def resource_name
    return nil unless resource
    
    if resource.respond_to?(:name)
      resource.name
    elsif resource.respond_to?(:title)
      resource.title
    else
      "#{resource.class.name} ##{resource.id}"
    end
  end

  def resource_attributes
    return nil unless resource
    
    # Get only safe attributes (exclude sensitive data)
    safe_attributes = resource.attributes.except(
      'password_digest', 'password', 'password_confirmation',
      'token', 'secret', 'api_key'
    )
    
    # Limit the size to prevent huge details
    safe_attributes.to_s[0..1000]
  end

  # Class methods for convenience
  class << self
    def log_login(administrator, request)
      new(
        administrator: administrator,
        action: 'login',
        request: request,
        details: { login_time: Time.current }
      ).call
    end

    def log_logout(administrator, request)
      new(
        administrator: administrator,
        action: 'logout',
        request: request,
        details: { logout_time: Time.current }
      ).call
    end

    def log_action(administrator, action, request, resource: nil, details: nil)
      new(
        administrator: administrator,
        action: action,
        request: request,
        resource: resource,
        details: details
      ).call
    end
  end
end
