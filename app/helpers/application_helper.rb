module ApplicationHelper
  # Generate `{controller}-{action}-page` class for body element
  def body_class
    path = controller_path.tr('/_', '-')
    action_name_map = {
      index: 'index',
      new: 'edit',
      edit: 'edit',
      update: 'edit',
      patch: 'edit',
      create: 'edit',
      destory: 'index'
    }
    mapped_action_name = action_name_map[action_name.to_sym] || action_name
    body_class_page = format('%s-%s-page', path, mapped_action_name)
    body_class_page
  end

  # Admin active for helper
  def admin_active_for(controller_name, navbar_name)
    if controller_name.to_s == admin_root_path
      return controller_name.to_s == navbar_name.to_s ? "active" : ""
    end
    navbar_name.to_s.include?(controller_name.to_s) ? 'active' : ''
  end

  def current_path
    request.env['PATH_INFO']
  end


  # Flash message class helper
  def flash_alert_class(level)
    case level.to_sym
    when :notice, :success
      'bg-green-100 text-green-800 border border-green-200'
    when :info
      'bg-blue-100 text-blue-800 border border-blue-200'
    when :warning
      'bg-yellow-100 text-yellow-800 border border-yellow-200'
    when :alert, :error
      'bg-red-100 text-red-800 border border-red-200'
    else
      'bg-blue-100 text-blue-800 border border-blue-200'
    end
  end

  # Dynamic validation helpers for admin forms
  def field_required?(model, field_name)
    model.class.validators_on(field_name.to_sym).any? { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
  end

  # This prevents AI from trying to add non-existent themes
  def paginate(scope, **options)
    super(scope, **options.except(:theme))
  end

  # Action badge class for operation logs
  def action_badge_class(action)
    case action
    when 'login'
      'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800'
    when 'logout'
      'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800'
    when 'create'
      'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800'
    when 'update'
      'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800'
    when 'destroy'
      'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800'
    else
      'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
    end
  end
end
