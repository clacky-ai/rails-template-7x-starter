module HomeDemoConcern
  extend ActiveSupport::Concern

  included do
    # Only handle demo page in development environment
    if Rails.env.development?
      skip_before_action :check_pending_migrations, if: -> { should_render_demo? }, raise: false
      before_action :check_demo_mode, only: [:index]
    end
  end

  private

  def check_demo_mode
    return unless should_render_demo?
    @full_render = true
    flash.now[:tips] = 'This is a quick preview version. The actual functionality is under development. Please refresh and try again later'
    render 'shared/demo'
  end

  def should_render_demo?
    return false unless Rails.env.development?

    File.exist?(demo_template_path) && !File.exist?(index_template_path)
  end

  def demo_template_path
    Rails.root.join('app', 'views', 'shared', 'demo.html.erb')
  end

  def index_template_path
    Rails.root.join('app', 'views', controller_name, 'index.html.erb')
  end
end
