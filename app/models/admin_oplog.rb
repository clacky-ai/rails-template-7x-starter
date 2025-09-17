class AdminOplog < ApplicationRecord
  belongs_to :administrator

  validates :action, presence: true
  validates :ip_address, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_administrator, ->(admin_id) { where(administrator_id: admin_id) }
  scope :by_resource, ->(type, id) { where(resource_type: type, resource_id: id) }

  # Human readable action names
  ACTION_LABELS = {
    'login' => 'Login',
    'logout' => 'Logout',
    'create' => 'Create',
    'update' => 'Update',
    'destroy' => 'Delete',
    'show' => 'View',
    'index' => 'List'
  }.freeze

  def action_label
    ACTION_LABELS[action] || action&.humanize
  end

  def resource_name
    return 'N/A' unless resource_type && resource_id
    
    begin
      resource_class = resource_type.constantize
      resource = resource_class.find_by(id: resource_id)
      if resource.respond_to?(:name)
        resource.name
      elsif resource.respond_to?(:title)
        resource.title
      else
        "#{resource_type} ##{resource_id}"
      end
    rescue
      "#{resource_type} ##{resource_id}"
    end
  end

  def short_user_agent
    return 'N/A' unless user_agent.present?
    
    # Extract browser info from user agent
    if user_agent.include?('Chrome')
      'Chrome'
    elsif user_agent.include?('Firefox')
      'Firefox'
    elsif user_agent.include?('Safari')
      'Safari'
    elsif user_agent.include?('Edge')
      'Edge'
    else
      'Other'
    end
  end
end
