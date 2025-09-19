module HomeStaticConcern
  extend ActiveSupport::Concern

  included do
    skip_before_action :check_pending_migrations, if: -> { should_render_static? }, raise: false
    before_action :check_static_mode, only: [:index]
  end

  private

  def check_static_mode
    return unless should_render_static?
    @full_render = true
    flash.now[:warning] = 'This is a quick preview version. The actual functionality is under development. Please refresh and try again later'
    render 'shared/static'
  end

  def should_render_static?
    return false unless Rails.env.development?

    File.exist?(static_template_path) && !File.exist?(index_template_path)
  end

  def static_template_path
    Rails.root.join('app', 'views', 'shared', 'static.html.erb')
  end

  def index_template_path
    Rails.root.join('app', 'views', controller_name, 'index.html.erb')
  end
end
