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
      'alert-success'
    when :info
      'alert-info'
    when :warning
      'alert-warning'
    when :alert, :error, :danger
      'alert-danger'
    when :tips
      'alert-warning'
    else
      'alert-info'
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
      'badge-success dark:badge-success'
    when 'logout'
      'badge-secondary dark:badge-secondary'
    when 'create'
      'badge-secondary dark:badge-secondary'
    when 'update'
      'badge-warning dark:badge-warning'
    when 'destroy'
      'badge-danger dark:badge-danger'
    else
      'badge-neutral dark:badge-neutral'
    end
  end
end
