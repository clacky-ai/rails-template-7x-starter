# config/initializers/override_welcome_controller.rb
Rails.application.config.to_prepare do
  next unless defined?(Rails::WelcomeController)

  Rails::WelcomeController.class_eval do
    def index
      # Use static HTML file from public directory
      static_file = Rails.root.join("public/missing_welcome_index.html")
      render file: static_file, layout: false, content_type: 'text/html'
    end
  end
end
